#pragma once
// Large verified pieces need a progress-aware opening window. These remain
// hard bounds across candidate switches; a codec check never resets them.
constexpr double RWStartupLimitSeconds=150;
constexpr double RWDiscoveryLimitSeconds=100;
constexpr double RWSourceOpeningLimitSeconds=60;
