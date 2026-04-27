// -----------------------------------------------------------------------------
//  AUTO-GENERATED FILE — apx.rest
//  Do not modify this file directly.
// -----------------------------------------------------------------------------
//  Generated on: 2026-04-27T00:21:14.041Z
//  Source OpenAPI document: C:\Sandbox\DotnetTemplates\WebProject\WebProject.Api\obj\WebProject.Api.json
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

export type TCheckoutVariantResponseDto = { 
	variant: string;
	description: string;
	total: number;
};

export class CheckoutVariantResponse {
	public variant: string;
	public description: string;
	public total: number;

	public constructor(dto: TCheckoutVariantResponseDto) {
		this.variant = dto.variant;
		this.description = dto.description;
		this.total = dto.total;
	}
}

export type TFeatureFlagsResponseDto = { 
	flags: Record<string, boolean>;
};

export class FeatureFlagsResponse {
	public flags: Map<string, boolean>;

	public constructor(dto: TFeatureFlagsResponseDto) {
		this.flags = new Map(Object.entries(dto.flags).map(([key, value]) => [key, value]));
	}
}

export type TSampleUnionResponseDto = { 
	option1?: TSampleOption1Dto;
	option2?: TSampleOption2Dto;
};

export class SampleUnionResponse {
	public option1?: SampleOption1;
	public option2?: SampleOption2;

	public constructor(dto: TSampleUnionResponseDto) {
		this.option1 = dto.option1 ? new SampleOption1(dto.option1) : undefined;
		this.option2 = dto.option2 ? new SampleOption2(dto.option2) : undefined;
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
	age: number;
};

export class SampleOption2 {
	public age: number;

	public constructor(dto: TSampleOption2Dto) {
		this.age = dto.age;
	}
}

export class MyApiClient extends ApiClient {
	public constructor() {
		super(import.meta.env.VITE_API_BASE_URL);
	}

	public async getFeatureFlags(options?: TApiRequestOptions): Promise<TApiClientResult<FeatureFlagsResponse>> {

		const { response, data } = await this.get<TFeatureFlagsResponseDto>(`feature-flags`, options);

		if (!response.ok || !data) {
			return [null, response];
		}

		return [new FeatureFlagsResponse(data), response]; 
	}
	public async getCheckoutVariant(options?: TApiRequestOptions): Promise<TApiClientResult<CheckoutVariantResponse>> {

		const { response, data } = await this.get<TCheckoutVariantResponseDto>(`checkout-variant`, options);

		if (!response.ok || !data) {
			return [null, response];
		}

		return [new CheckoutVariantResponse(data), response]; 
	}
	public async getSampleUnionResponse(options?: TApiRequestOptions): Promise<TApiClientResult<SampleUnionResponse>> {

		const { response, data } = await this.get<TSampleUnionResponseDto>(`sample-union`, options);

		if (!response.ok || !data) {
			return [null, response];
		}

		return [new SampleUnionResponse(data), response]; 
	}
}