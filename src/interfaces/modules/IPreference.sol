// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

struct RebasePereferenceParams {
    int24 upperPreference;
    int24 lowerPreference;
    int24 lowerBaseThreshold; // need to figure this out
    int24 upperBaseThreshold; // need to figure this out
    int8 upperPercentage;
    int8 lowerPercentage;
}

interface IPreference {
    error InvalidCaller();
}
