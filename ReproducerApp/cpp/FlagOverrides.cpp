// An app turns on one flag above the experimental release channel's values.
#include <memory>

#include <react/featureflags/ReactNativeFeatureFlags.h>
#include <react/featureflags/ReactNativeFeatureFlagsOverridesOSSExperimental.h>

namespace sample {

class Overrides : public facebook::react::ReactNativeFeatureFlagsOverridesOSSExperimental {
 public:
  bool preventShadowTreeCommitExhaustion() override {
    return true;
  }
};

void overrideFlags() {
  facebook::react::ReactNativeFeatureFlags::override(std::make_unique<Overrides>());
}

} // namespace sample
