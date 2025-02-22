import enum Yosemite.CreateAccountError

extension WooAnalyticsEvent {
    enum StoreCreation {
        /// Event property keys.
        private enum Key {
            static let source = "source"
            static let url = "url"
            static let errorType = "error_type"
            static let flow = "flow"
            static let step = "step"
            static let category = "industry"
            static let categoryGroup = "industry_group"
            static let sellingStatus = "user_commerce_journey"
            static let sellingPlatforms = "ecommerce_platforms"
            static let countryCode = "country_code"
        }

        /// Tracked when the user taps on the CTA in store picker (logged in to WPCOM) to create a store.
        static func sitePickerCreateSiteTapped(source: StorePickerSource) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .sitePickerCreateSiteTapped,
                              properties: [Key.source: source.rawValue])
        }

        /// Tracked when a site is created from the store creation flow.
        static func siteCreated(source: Source, siteURL: String, flow: Flow) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .siteCreated,
                              properties: [Key.source: source.rawValue,
                                           Key.url: siteURL,
                                           Key.flow: flow.rawValue])
        }

        /// Tracked when site creation fails.
        static func siteCreationFailed(source: Source, error: Error, flow: Flow) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .siteCreationFailed,
                              properties: [Key.source: source.rawValue, Key.flow: flow.rawValue],
                              error: error)
        }

        /// Tracked when the user dismisses the store creation flow before the flow is complete.
        static func siteCreationDismissed(source: Source, flow: Flow) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .siteCreationDismissed,
                              properties: [Key.source: source.rawValue, Key.flow: flow.rawValue])
        }

        /// Tracked when the user reaches each step of the store creation flow.
        static func siteCreationStep(step: Step) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .siteCreationStep,
                              properties: [Key.step: step.rawValue])
        }

        /// Tracked clicking on “Store Preview” button after a site is created successfully.
        static func siteCreationSitePreviewed() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .siteCreationSitePreviewed, properties: [:])
        }

        /// Tracked when tapping on the “Manage my store” button on the store creation success screen.
        static func siteCreationManageStoreTapped() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .siteCreationManageStoreTapped, properties: [:])
        }

        /// Tracked when completing the last profiler question during the store creation flow.
        static func siteCreationProfilerData(category: StoreCreationCategoryAnswer?,
                                             sellingStatus: StoreCreationSellingStatusAnswer?,
                                             countryCode: SiteAddress.CountryCode?) -> WooAnalyticsEvent {
            let properties = [
                Key.category: category?.value,
                Key.categoryGroup: category?.groupValue,
                Key.sellingStatus: sellingStatus?.sellingStatus.rawValue,
                Key.sellingPlatforms: sellingStatus?.sellingPlatforms?.map { $0.rawValue }.sorted().joined(separator: ","),
                Key.countryCode: countryCode?.rawValue
            ].compactMapValues({ $0 })
            return WooAnalyticsEvent(statName: .siteCreationProfilerData, properties: properties)
        }

        /// Tracked when the user taps on the CTA in login prologue (logged out) to create a store.
        static func loginPrologueCreateSiteTapped() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .loginPrologueCreateSiteTapped,
                              properties: [:])
        }

        /// Tracked when the user taps on the CTA in the account creation form to log in instead.
        static func signupFormLoginTapped() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .signupFormLoginTapped,
                              properties: [:])
        }

        /// Tracked when the user taps to submit the WPCOM signup form.
        static func signupSubmitted() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .signupSubmitted,
                              properties: [:])
        }

        /// Tracked when WPCOM signup succeeds.
        static func signupSuccess() -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .signupSuccess,
                              properties: [:])
        }

        /// Tracked when WPCOM signup fails.
        static func signupFailed(error: CreateAccountError) -> WooAnalyticsEvent {
            WooAnalyticsEvent(statName: .signupFailed,
                              properties: [Key.errorType: error.analyticsValue])
        }
    }
}

extension WooAnalyticsEvent.StoreCreation {
    enum StorePickerSource: String {
        /// From switching stores.
        case switchStores = "switching_stores"
        /// From the login flow.
        case login
        /// The store creation flow is originally initiated from login prologue and dismissed,
        /// which lands on the store picker.
        case loginPrologue = "prologue"
        /// Other sources like from any error screens during the login flow.
        case other
    }

    enum Source: String {
        case loginPrologue = "prologue"
        case storePicker = "store_picker"
        case loginEmailError = "login_email_error"
    }

    /// The implementation of store creation flow - native (M2) or web (M1).
    enum Flow: String {
        case native = "native"
        case web = "web"
    }

    /// Steps of the native store creation flow.
    enum Step: String {
        case storeName = "store_name"
        case profilerCategoryQuestion = "store_profiler_industries"
        case profilerSellingStatusQuestion = "store_profiler_commerce_journey"
        case profilerCountryQuestion = "store_profiler_country"
        case domainPicker = "domain_picker"
        case storeSummary = "store_summary"
        case planPurchase = "plan_purchase"
        case webCheckout = "web_checkout"
        case storeInstallation = "store_installation"
    }
}

private extension CreateAccountError {
    var analyticsValue: String {
        switch self {
        case .emailExists:
            return "EMAIL_EXIST"
        case .invalidEmail:
            return "EMAIL_INVALID"
        case .invalidPassword:
            return "PASSWORD_INVALID"
        default:
            return "\(self)"
        }
    }
}
