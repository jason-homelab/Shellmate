import SwiftUI

extension DesignTokens {

    enum Animation {
        static let springResponse: Double = 0.35
        static let springDamping:  Double = 0.75

        static let standard = SwiftUI.Animation.easeInOut(duration: 0.20)
        static let fast     = SwiftUI.Animation.easeInOut(duration: 0.10)
        static let medium   = SwiftUI.Animation.easeInOut(duration: 0.30)
        static let slow     = SwiftUI.Animation.easeInOut(duration: 0.50)
        static let spring   = SwiftUI.Animation.spring(response: springResponse, dampingFraction: springDamping)
        static let glass    = SwiftUI.Animation.spring(response: 0.40, dampingFraction: 0.80)
        static let hover    = SwiftUI.Animation.easeOut(duration: 0.12)
    }
}
