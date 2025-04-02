import SwiftUI

struct HelpTooltipView: View {
    let message: String
    let icon: String
    @Binding var isVisible: Bool
    var arrowPosition: ArrowPosition = .bottom
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    enum ArrowPosition {
        case top, bottom, left, right, none
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Close button in corner
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
            }
            .padding(.top, -8)
            .padding(.trailing, -8)
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white)
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
            
            // Message
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Optional action button
            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.footnote.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, arrowPosition == .top ? 12 : 0)
        .padding(.bottom, arrowPosition == .bottom ? 12 : 0)
        .padding(.leading, arrowPosition == .left ? 12 : 0)
        .padding(.trailing, arrowPosition == .right ? 12 : 0)
        .padding(16)
        .background(
            ZStack {
                // Tooltip background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                // Arrow based on position
                GeometryReader { geo in
                    Path { path in
                        switch arrowPosition {
                        case .bottom:
                            let arrowWidth: CGFloat = 14
                            let arrowHeight: CGFloat = 8
                            let arrowX = geo.size.width / 2 - arrowWidth / 2
                            
                            path.move(to: CGPoint(x: arrowX, y: geo.size.height))
                            path.addLine(to: CGPoint(x: arrowX + arrowWidth / 2, y: geo.size.height + arrowHeight))
                            path.addLine(to: CGPoint(x: arrowX + arrowWidth, y: geo.size.height))
                        case .top:
                            let arrowWidth: CGFloat = 14
                            let arrowHeight: CGFloat = 8
                            let arrowX = geo.size.width / 2 - arrowWidth / 2
                            
                            path.move(to: CGPoint(x: arrowX, y: 0))
                            path.addLine(to: CGPoint(x: arrowX + arrowWidth / 2, y: -arrowHeight))
                            path.addLine(to: CGPoint(x: arrowX + arrowWidth, y: 0))
                        case .left:
                            let arrowWidth: CGFloat = 8
                            let arrowHeight: CGFloat = 14
                            let arrowY = geo.size.height / 2 - arrowHeight / 2
                            
                            path.move(to: CGPoint(x: 0, y: arrowY))
                            path.addLine(to: CGPoint(x: -arrowWidth, y: arrowY + arrowHeight / 2))
                            path.addLine(to: CGPoint(x: 0, y: arrowY + arrowHeight))
                        case .right:
                            let arrowWidth: CGFloat = 8
                            let arrowHeight: CGFloat = 14
                            let arrowY = geo.size.height / 2 - arrowHeight / 2
                            
                            path.move(to: CGPoint(x: geo.size.width, y: arrowY))
                            path.addLine(to: CGPoint(x: geo.size.width + arrowWidth, y: arrowY + arrowHeight / 2))
                            path.addLine(to: CGPoint(x: geo.size.width, y: arrowY + arrowHeight))
                        case .none:
                            break
                        }
                    }
                    .fill(Color.black.opacity(0.8))
                }
            }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
        .zIndex(100)
    }
}

struct FloatingTutorialManager: View {
    @AppStorage("completedTutorials") private var completedTutorials = ""
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @State private var currentTip: TutorialTip?
    @State private var showTip = false
    
    // Track number of app launches
    @AppStorage("appLaunchCount") private var appLaunchCount = 0
    
    // Flag to determine if this is the first app session after onboarding
    private var isFirstSessionAfterOnboarding: Bool {
        return appLaunchCount <= 1 && isOnboardingCompleted
    }
    
    enum TutorialTip: String, CaseIterable {
        case mapExpand = "mapExpandTip"
        case addLocation = "addLocationTip"
        case searchRadius = "searchRadiusTip"
        case filterResults = "filterResultsTip"
        
        var message: String {
            switch self {
            case .mapExpand:
                return "Tap this button to expand the map to full screen for better interaction"
            case .addLocation:
                return "Add locations by searching, using current location, or long-pressing on the map"
            case .searchRadius:
                return "Adjust the search radius to find more places in the area"
            case .filterResults:
                return "Search for categories like 'food' or 'coffee' to find what you need"
            }
        }
        
        var icon: String {
            switch self {
            case .mapExpand:
                return "arrow.up.left.and.arrow.down.right"
            case .addLocation:
                return "plus"
            case .searchRadius:
                return "circle.dashed"
            case .filterResults:
                return "line.3.horizontal.decrease"
            }
        }
        
        var arrowPosition: HelpTooltipView.ArrowPosition {
            switch self {
            case .mapExpand:
                return .right
            case .addLocation:
                return .bottom
            case .searchRadius:
                return .left
            case .filterResults:
                return .top
            }
        }
    }
    
    // Anchor points for tooltips
    var mapExpandAnchor: Anchor<CGPoint>?
    var addLocationAnchor: Anchor<CGPoint>?
    var filterResultsAnchor: Anchor<CGPoint>?
    var searchRadiusAnchor: Anchor<CGPoint>?
    
    var body: some View {
        ZStack {
            if let tip = currentTip, showTip {
                // Position tooltip based on tip type
                switch tip {
                case .mapExpand:
                    if let anchor = mapExpandAnchor {
                        HelpTooltipView(
                            message: tip.message,
                            icon: tip.icon,
                            isVisible: $showTip,
                            arrowPosition: tip.arrowPosition,
                            actionLabel: "Got it",
                            action: { markTipAsCompleted() }
                        )
                        .frame(width: 230)
                        .anchorPreference(key: ViewAnchorKey.self, value: .bounds) { _ in
                            [ViewAnchorKey.ID.tooltip: anchor]
                        }
                    }
                
                case .addLocation:
                    if let anchor = addLocationAnchor {
                        HelpTooltipView(
                            message: tip.message,
                            icon: tip.icon,
                            isVisible: $showTip,
                            arrowPosition: tip.arrowPosition,
                            actionLabel: "Got it",
                            action: { markTipAsCompleted() }
                        )
                        .frame(width: 270)
                        .anchorPreference(key: ViewAnchorKey.self, value: .bounds) { _ in
                            [ViewAnchorKey.ID.tooltip: anchor]
                        }
                    }
                
                case .filterResults:
                    if let anchor = filterResultsAnchor {
                        HelpTooltipView(
                            message: tip.message,
                            icon: tip.icon,
                            isVisible: $showTip,
                            arrowPosition: tip.arrowPosition,
                            actionLabel: "Got it",
                            action: { markTipAsCompleted() }
                        )
                        .frame(width: 230)
                        .anchorPreference(key: ViewAnchorKey.self, value: .bounds) { _ in
                            [ViewAnchorKey.ID.tooltip: anchor]
                        }
                    }
                    
                case .searchRadius:
                    if let anchor = searchRadiusAnchor {
                        HelpTooltipView(
                            message: tip.message,
                            icon: tip.icon,
                            isVisible: $showTip,
                            arrowPosition: tip.arrowPosition,
                            actionLabel: "Got it",
                            action: { markTipAsCompleted() }
                        )
                        .frame(width: 230)
                        .anchorPreference(key: ViewAnchorKey.self, value: .bounds) { _ in
                            [ViewAnchorKey.ID.tooltip: anchor]
                        }
                    }
                }
            }
        }
        .onAppear {
            // Increment app launch counter
            appLaunchCount += 1
            
            // Only show tips on first launch after onboarding
            if isFirstSessionAfterOnboarding && !allTipsCompleted() {
                // Show tips progressively after completing onboarding
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showNextTip()
                }
            }
        }
    }
    
    // Check if all tips have been shown
    private func allTipsCompleted() -> Bool {
        let completed = completedTutorials.components(separatedBy: ",")
        return TutorialTip.allCases.allSatisfy { completed.contains($0.rawValue) }
    }
    
    func showNextTip() {
        // Convert completed tutorials string to array
        let completed = completedTutorials.components(separatedBy: ",")
        
        // Find the first uncompleted tip
        if let nextTip = TutorialTip.allCases.first(where: { !completed.contains($0.rawValue) }) {
            currentTip = nextTip
            
            withAnimation(.easeIn(duration: 0.3)) {
                showTip = true
            }
        }
    }
    
    func markTipAsCompleted() {
        guard let tip = currentTip else { return }
        
        // Add to completed tutorials
        let completed = completedTutorials.components(separatedBy: ",")
        if !completed.contains(tip.rawValue) {
            if completedTutorials.isEmpty {
                completedTutorials = tip.rawValue
            } else {
                completedTutorials += ",\(tip.rawValue)"
            }
        }
        
        // Hide current tip
        withAnimation(.easeOut(duration: 0.3)) {
            showTip = false
        }
        
        // Show next tip after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showNextTip()
        }
    }
}

// Anchor preference key for positioning tooltips
struct ViewAnchorKey: PreferenceKey {
    static var defaultValue: [ID: Anchor<CGPoint>] = [:]
    
    static func reduce(value: inout [ID: Anchor<CGPoint>], nextValue: () -> [ID: Anchor<CGPoint>]) {
        value.merge(nextValue()) { $1 }
    }
    
    enum ID {
        case tooltip
        case mapExpandButton
        case addLocationButton
        case searchRadius
        case filterButton
    }
} 