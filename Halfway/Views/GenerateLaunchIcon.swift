import SwiftUI

struct GenerateLaunchIcon: View {
    var body: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.indigo]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 512, height: 512)
            
            // Map grid lines (horizontal)
            VStack(spacing: 30) {
                ForEach(0..<10) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                }
            }
            .frame(width: 400)
            
            // Map grid lines (vertical)
            HStack(spacing: 30) {
                ForEach(0..<10) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1)
                }
            }
            .frame(height: 400)
            
            // Midpoint path lines
            Path { path in
                path.move(to: CGPoint(x: 150, y: 256))
                path.addLine(to: CGPoint(x: 256, y: 256))
                path.addLine(to: CGPoint(x: 362, y: 256))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [5, 5]))
            
            // Location pins
            ZStack {
                // First location pin
                LocationPin(color: .blue)
                    .frame(width: 80, height: 80)
                    .offset(x: -106, y: 0)
                
                // Second location pin
                LocationPin(color: .green)
                    .frame(width: 80, height: 80)
                    .offset(x: 106, y: 0)
                
                // Midpoint star
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(50)
        .background(Color.clear)
    }
}

struct LocationPin: View {
    var color: Color
    
    var body: some View {
        ZStack {
            // Pin body
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }
}

struct GenerateLaunchIcon_Previews: PreviewProvider {
    static var previews: some View {
        GenerateLaunchIcon()
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 