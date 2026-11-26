import Foundation
import Testing
@testable import StarHashKit

@Suite("Radar placement", .english)
struct RadarPlacementTests {
    /// Closer is nearer the middle, and the close steps read apart more
    /// than the far ones.
    @Test func reachGrowsWithDistanceCloseStepsMost() {
        #expect(RadarPlacement.reach(distance: 0) == 0)
        #expect(RadarPlacement.reach(distance: RadarPlacement.farthest) == 1)
        #expect(RadarPlacement.reach(distance: 50) == 1)
        let half = RadarPlacement.reach(distance: 0.5), one = RadarPlacement.reach(distance: 1)
        let eight = RadarPlacement.reach(distance: 8), nine = RadarPlacement.reach(distance: 9)
        #expect(half < one && one < eight && eight < nine)
        #expect(one - half > nine - eight)
        #expect(RadarPlacement.reach(distance: -1) == 0)
        #expect(RadarPlacement.reach(distance: .nan) == 0)
    }

    @Test func bearingIsLeftOrRightOfStraightAhead() throws {
        #expect(RadarPlacement.bearing(direction: nil) == nil)
        #expect(RadarPlacement.bearing(direction: SIMD3(0, 0, -1)) == 0)
        let right = try #require(RadarPlacement.bearing(direction: SIMD3(1, 0, 0)))
        #expect(abs(right - .pi / 2) < 0.0001)
        let left = try #require(RadarPlacement.bearing(direction: SIMD3(-0.5, 0, -0.866)))
        #expect(abs(left + .pi / 6) < 0.001)
    }

    @Test func pointingFindsWhoIsStraightAhead() {
        #expect(RadarPlacement.isPointedAt(bearing: 0))
        #expect(RadarPlacement.isPointedAt(bearing: 10 * .pi / 180))
        #expect(RadarPlacement.isPointedAt(bearing: -10 * .pi / 180))
        #expect(!RadarPlacement.isPointedAt(bearing: 20 * .pi / 180))
        #expect(!RadarPlacement.isPointedAt(bearing: nil))
    }

    /// A jittery reading moves the placement only part of the way, and a
    /// missing direction keeps the last one.
    @Test func placementIsSteadiedAndKeepsItsLastDirection() throws {
        var placement = RadarPlacement.Smoothed()
        #expect(placement.reach == nil && placement.bearing == nil)
        placement.add(distance: 4, bearing: 0.2)
        #expect(placement.reach == RadarPlacement.reach(distance: 4) && placement.bearing == 0.2)
        placement.add(distance: 9, bearing: nil)
        let reach = try #require(placement.reach)
        #expect(reach > RadarPlacement.reach(distance: 4) && reach < RadarPlacement.reach(distance: 9))
        #expect(placement.bearing == 0.2)
        #expect(placement.distance == 9)
        placement.add(distance: nil, bearing: -0.2)
        let bearing = try #require(placement.bearing)
        #expect(bearing < 0.2 && bearing > -0.2)
    }

    @Test func distanceIsSaidSimply() {
        #expect(RadarPlacement.spoken(distance: 0.42) == "40 cm")
        #expect(RadarPlacement.spoken(distance: 0.02) == "10 cm")
        #expect(RadarPlacement.spoken(distance: 2.46) == "2.5 m")
        #expect(RadarPlacement.spoken(distance: 12.4) == "12 m")
    }
}
