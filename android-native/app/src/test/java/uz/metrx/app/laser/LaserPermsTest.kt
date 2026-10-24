package uz.metrx.app.laser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** What the laser pages ask for on each Android (laser/LaserLog.kt LaserPerms). */
class LaserPermsTest {
    private val fine = "android.permission.ACCESS_FINE_LOCATION"
    private val coarse = "android.permission.ACCESS_COARSE_LOCATION"
    private val scan = "android.permission.BLUETOOTH_SCAN"
    private val connect = "android.permission.BLUETOOTH_CONNECT"

    @Test fun upToAndroid11FineAndCoarseLocationTogether() {
        for (sdk in listOf(26, 27, 29, 30)) assertEquals(listOf(fine, coarse), LaserPerms.needed(sdk))
    }

    @Test fun fromAndroid12OnlyBluetoothNoLocation() {
        // the manifest says neverForLocation; asking FINE alone on 12+ would be refused (it needs COARSE with it)
        for (sdk in listOf(31, 33, 34, 36)) {
            assertEquals(listOf(scan, connect), LaserPerms.needed(sdk))
            assertFalse(LaserPerms.needed(sdk).contains(fine))
        }
    }

    @Test fun locationServicesAndTheWordsFollowTheSameLine() {
        assertTrue(LaserPerms.locNeeded(30)); assertFalse(LaserPerms.locNeeded(31))
        assertEquals("lt.perm", LaserPerms.permKey(30)); assertEquals("lz.permBt", LaserPerms.permKey(31))
    }
}
