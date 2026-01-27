import {
	handler,
	HTTPCapability,
	HTTPClient,
	type HTTPPayload,
	type HTTPSendRequester,
	Runner,
	type Runtime,
	decodeJson,
	ConsensusAggregationByFields,
	median,
} from '@chainlink/cre-sdk'
import { z } from 'zod'

// Config schema - simplified to only require authorized keys for HTTP trigger
const configSchema = z.object({
	authorizedKeys: z.array(
		z.object({
			type: z.enum(['KEY_TYPE_UNSPECIFIED', 'KEY_TYPE_ECDSA_EVM']),
			publicKey: z.string(),
		}),
	),
})

type Config = z.infer<typeof configSchema>

// Payload received from HTTP trigger
interface TriggerPayload {
	testCase: string
	url: string
}

// API response format from por-api-server
interface APIAsset {
	assetId: string
	name: string
	totalSupply: string
	totalReserves: string
	reserveRatio: number
	unit: string
	lastUpdated: string
}

interface APIResponse {
	timestamp: string
	assets: APIAsset[]
	status: string
	padding?: string
}

// Result of fetching reserve info
interface ReserveInfo {
	lastUpdated: Date
	totalReserves: number
	totalSupply: number
}

// Workflow result returned to caller
interface WorkflowResult {
	testCase: string
	url: string
	success: boolean
	statusCode?: number
	error?: string
	data?: ReserveInfo
}

// Utility function to safely stringify objects with bigints and dates
const safeJsonStringify = (obj: unknown): string =>
	JSON.stringify(
		obj,
		(_, value) => {
			if (typeof value === 'bigint') return value.toString()
			if (value instanceof Date) return value.toISOString()
			return value
		},
		2,
	)

// Function to fetch reserve info from the given URL
const fetchReserveInfo = (
	sendRequester: HTTPSendRequester,
	params: { url: string },
): ReserveInfo => {
	const response = sendRequester.sendRequest({ method: 'GET', url: params.url }).result()

	if (response.statusCode !== 200) {
		throw new Error(`HTTP request failed with status: ${response.statusCode}`)
	}

	const responseText = Buffer.from(response.body).toString('utf-8')
	const apiResp: APIResponse = JSON.parse(responseText)

	// Extract totals from assets array
	let totalReserves = 0
	let totalSupply = 0
	for (const asset of apiResp.assets) {
		totalReserves += Number(asset.totalReserves)
		totalSupply += Number(asset.totalSupply)
	}

	return {
		lastUpdated: new Date(apiResp.timestamp),
		totalReserves,
		totalSupply,
	}
}

// HTTP trigger callback - processes test case requests
const onHttpTrigger = (runtime: Runtime<Config>, payload: HTTPPayload): string => {
	// Decode the input payload
	const input = decodeJson(payload.input) as TriggerPayload

	// Validate required fields
	if (!input.testCase) {
		throw new Error('Missing required field: testCase')
	}
	if (!input.url) {
		throw new Error('Missing required field: url')
	}

	// Log the test case at the start
	runtime.log(`Starting test case: ${input.testCase}`)
	runtime.log(`URL: ${input.url}`)

	const result: WorkflowResult = {
		testCase: input.testCase,
		url: input.url,
		success: false,
	}

	try {
		// Create HTTP client and fetch data
		const httpClient = new HTTPClient()

		runtime.log(`Fetching data from URL...`)

		const reserveInfo = httpClient
			.sendRequest(
				runtime,
				fetchReserveInfo,
				ConsensusAggregationByFields<ReserveInfo>({
					lastUpdated: median,
					totalReserves: median,
					totalSupply: median,
				}),
			)({ url: input.url })
			.result()

		runtime.log(`Successfully fetched reserve info`)
		runtime.log(`Reserve Info: ${safeJsonStringify(reserveInfo)}`)

		result.success = true
		result.statusCode = 200
		result.data = reserveInfo
	} catch (error) {
		const errorMessage = error instanceof Error ? error.message : String(error)
		runtime.log(`Test case failed with error: ${errorMessage}`)
		result.success = false
		result.error = errorMessage
	}

	runtime.log(`Test case ${input.testCase} completed`)
	runtime.log(`Success: ${result.success}`)

	return safeJsonStringify(result)
}

// Initialize the workflow with HTTP trigger
const initWorkflow = (config: Config) => {
	const httpCapability = new HTTPCapability()

	return [
		handler(
			httpCapability.trigger({
				authorizedKeys: config.authorizedKeys,
			}),
			onHttpTrigger,
		),
	]
}

export async function main() {
	const runner = await Runner.newRunner<Config>({
		configSchema,
	})
	await runner.run(initWorkflow)
}
