import { useState } from "react";

export type TUseStreamedRequestOptions<TResponse> = { 
	requestFn: () => AsyncIterable<TResponse>;
	onStreamEvent?: (data: TResponse) => void;
	onSettled?: () => void;
	onComplete?: () => void;
	onError?: (error: unknown) => void;
}

export enum StreamedResponseStatus { 
	Idle,
	Active,
	Success,
	Failure
}

export type TUseStreamedRequestResult<TResponse> = { 
	data: TResponse[] | null;
	error: Error | null;
	isActive: boolean;
	isIdle: boolean;
	isSuccess: boolean;
	isFailure: boolean;
	status: StreamedResponseStatus;
	run: () => Promise<void>;
	reset: () => void; 
}

export default function useStreamedRequest<TResponse>( { 
	requestFn, 
	onStreamEvent,
	onSettled,
	onComplete: onComplete,
	onError
}: TUseStreamedRequestOptions<TResponse>) : TUseStreamedRequestResult<TResponse> { 
	const [data, setData] = useState<TResponse[] | null>(null);
	const [error, setError] = useState<unknown>(null);
	const [status, setStatus] = useState<StreamedResponseStatus>(StreamedResponseStatus.Idle);
	const isActive = status === StreamedResponseStatus.Active;
	const isIdle = status === StreamedResponseStatus.Idle;
	const isSuccess = status === StreamedResponseStatus.Success;
	const isFailure = status === StreamedResponseStatus.Failure;

	function reset() { 
		setData(null);
		setError(null);
		setStatus(StreamedResponseStatus.Idle);
	}

	async function run() {
		setStatus(StreamedResponseStatus.Active);
		setData([]);
		setError(null);
		try {
			for await (const response of requestFn()) {
				setData((prevData) => (prevData ? [...prevData, response] : [response]));
				onStreamEvent?.(response);
			}
			setStatus(StreamedResponseStatus.Success);
			onComplete?.();
		} catch (err) {
			setError(err);
			onError?.(err);	
		} finally {
			setStatus(StreamedResponseStatus.Idle);
			onSettled?.();
		}
	}

	return { 
		data: data,
		error: error ? (error as Error) : null,
		isActive,
		isIdle,
		isSuccess,
		isFailure,
		status,
		run,
		reset
	};
}