// -----------------------------------------------------------------------------
//  AUTO-GENERATED FILE — apx.rest
//  Do not modify this file directly.
// -----------------------------------------------------------------------------
//  Generated on: 2026-02-18T02:38:51.974Z
//  Source OpenAPI document: https://localhost:7100/openapi/v1.json
//  This file will be overwritten on regeneration.
//
//  Regenerate with:
//    npx apx-gen
//
//  Customize generation with:
//    apx-rest-config.json
// -----------------------------------------------------------------------------

/* eslint-disable */

import { ApiClient, type TApiRequestOptions, type TApiClientResult } from "apx.rest";

export type TSampleUnionResponseDto = { 
	option1?: SampleOption1;
	option2?: SampleOption2;
};

export class SampleUnionResponse {
	public option1?: SampleOption1;
	public option2?: SampleOption2;

	public constructor(dto: TSampleUnionResponseDto) {
		this.option1 = dto.option1;
		this.option2 = dto.option2;
	}
	public switch(
		option1: (value: SampleOption1) => void,
		option2: (value: SampleOption2) => void		
	) : void {
		if (this.option1 !== undefined) {
			option1(this.option1);
			return;
		}
		if (this.option2 !== undefined) {
			option2(this.option2);
			return;
		}
		throw new Error("No matching type in union");
	}
	public match<TResult>(
		option1: (value: SampleOption1) => TResult,
		option2: (value: SampleOption2) => TResult
	) : TResult {
		if (this.option1 !== undefined) {
			return option1(this.option1);
		}
		if (this.option2 !== undefined) {
			return option2(this.option2);
		}
		throw new Error("No matching type in union");
	}
}

export type TSampleOption1Dto = { 
	name: string;
};

export class SampleOption1 {
	public name: string;

	public constructor(dto: TSampleOption1Dto) {
		this.name = dto.name;
	}
}

export type TSampleOption2Dto = { 
	age: undefined;
};

export class SampleOption2 {
	public age: undefined;

	public constructor(dto: TSampleOption2Dto) {
		this.age = dto.age;
	}
}

export class MyApiClient extends ApiClient {
	public constructor() {
		super(import.meta.env.VITE_API_BASE_URL);
	}

	public async getSampleUnionResponse(options?: TApiRequestOptions): Promise<TApiClientResult<SampleUnionResponse>> {

		const { response, data } = await this.get<TSampleUnionResponseDto>(`sample-union`, options);

		if (!response.ok || !data) {
			return [null, response];
		}

		return [new SampleUnionResponse(data), response]; 
	}
}