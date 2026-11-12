// A library on the commit path reads the flags its own commit hooks must agree with.
#include <react/featureflags/ReactNativeFeatureFlags.h>

namespace sample {

bool commitPathFlagsOn() {
  using facebook::react::ReactNativeFeatureFlags;
  return ReactNativeFeatureFlags::preventShadowTreeCommitExhaustion() &&
      ReactNativeFeatureFlags::enableFabricCommitBranching() &&
      ReactNativeFeatureFlags::updateRuntimeShadowNodeReferencesOnCommit() &&
      ReactNativeFeatureFlags::cxxNativeAnimatedEnabled() &&
      ReactNativeFeatureFlags::enableFlexboxAutoMinSizeInStrictMode();
}

} // namespace sample
