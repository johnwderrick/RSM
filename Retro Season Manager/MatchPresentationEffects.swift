//
//  MatchPresentationEffects.swift
//  Retro Season Manager
//
//  Additive presentation flourishes for the live match screen — CRT
//  scanlines, a small camera shake, and pixel-style crowd confetti.
//  Pure overlay/modifier effects, layered on top of the existing match
//  screen; none of this touches its core layout.
//

import SwiftUI

/// A persistent, subtle "watching through an old TV" texture — faint
/// scanlines, a vignette, and a slow, barely-there brightness flicker.
/// Cheap to render: the scanline pattern is static, only the outer
/// opacity animates.
struct CRTScanlineOverlay: View {
    @State private var flicker = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    let lineSpacing: CGFloat = 3
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                     with: .color(.black.opacity(0.07)))
                        y += lineSpacing
                    }
                }
                RadialGradient(colors: [.clear, .black.opacity(0.32)], center: .center,
                               startRadius: geo.size.width * 0.35, endRadius: geo.size.width * 0.8)
            }
        }
        .opacity(flicker ? 0.92 : 1.0)
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                flicker.toggle()
            }
        }
    }
}

/// A brief, small camera shake — classic decaying-sine wobble, driven by
/// bumping `trigger`. Kept small and rare on purpose: a broadcast jolt on
/// a big goal or red card, not a constant screen shake.
private struct MatchShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amplitude: CGFloat = 6

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amplitude * sin(shakes * 2 * .pi), y: 0))
    }
}

private struct MatchShakeModifier: ViewModifier {
    let trigger: Int
    @State private var shakes: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(MatchShakeEffect(shakes: shakes))
            .onChange(of: trigger) { _, _ in
                shakes = 3
                withAnimation(.easeOut(duration: 0.4)) { shakes = 0 }
            }
    }
}

extension View {
    /// Applies a brief camera shake every time `trigger` changes value —
    /// pass an incrementing counter from the call site.
    func matchShake(trigger: Int) -> some View {
        modifier(MatchShakeModifier(trigger: trigger))
    }
}

/// Small falling pixel squares in club colours — a lightweight stand-in
/// crowd celebration for goals and promotion/title moments, no physics
/// engine required.
struct PixelConfettiBurst: View {
    let colors: [Color]

    private struct Particle: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let color: Color
        let size: CGFloat
        let delay: Double
        let duration: Double
        let rotation: Double
    }

    @State private var particles: [Particle] = []
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Rectangle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .rotationEffect(.degrees(fallen ? particle.rotation : 0))
                        .position(x: particle.xFraction * geo.size.width,
                                 y: fallen ? geo.size.height + 40 : -20)
                        .opacity(fallen ? 0 : 1)
                        .animation(.easeIn(duration: particle.duration).delay(particle.delay), value: fallen)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            let palette = colors.isEmpty ? [Retro.gold, Retro.accent] : colors
            particles = (0..<28).map { _ in
                Particle(xFraction: CGFloat.random(in: 0...1),
                         color: palette.randomElement()!,
                         size: CGFloat.random(in: 5...10),
                         delay: Double.random(in: 0...0.3),
                         duration: Double.random(in: 1.0...1.8),
                         rotation: Double.random(in: 180...720))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fallen = true }
        }
    }
}
