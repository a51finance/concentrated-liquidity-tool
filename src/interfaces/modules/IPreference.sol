// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

struct RebasePereferenceParams {
    int24 upperPreference;
    int24 lowerPreference;
    int8 upperPercentage;
    int8 lowerPercentage;
}

interface IPreference {
    error InvalidCaller();
}
