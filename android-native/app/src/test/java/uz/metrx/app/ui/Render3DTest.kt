package uz.metrx.app.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.ui.three.BG3D
import uz.metrx.app.ui.three.Quality3D
import uz.metrx.app.ui.three.Studio
import uz.metrx.app.ui.three.pbrNeutral
import uz.metrx.app.ui.three.srgbToLinear
import uz.metrx.app.ui.three.untonemapped

/** The lit 3D's quality tiers, tone curve and studio light (modern 3D part 1). */
class Render3DTest {
    @Test fun theMi6xIsWeakAndAStrongPhoneIsNot() {
        // the founder's Mi 6X: Android 8.1, Adreno 512, 4 GB
        assertTrue(Quality3D.weakReasons(27, false, 3_700_000_000L, "Adreno (TM) 512").containsAll(listOf("sdk<29", "ram<4GB", "gpu")))
        assertTrue(Quality3D.weakReasons(34, false, 8_000_000_000L, "Adreno (TM) 740").isEmpty())
        assertTrue(Quality3D.weakReasons(34, true, 8_000_000_000L, null).contains("lowRam"))
        // the emulator on the PC's GPU, 4 GB
        assertTrue(Quality3D.weakReasons(37, false, 4_104_000_000L, "Android Emulator OpenGL ES Translator (NVIDIA GeForce RTX 5060 Laptop GPU/PCIe/SSE2)").isEmpty())
    }

    @Test fun weakGpus() {
        listOf("Adreno (TM) 506", "Adreno (TM) 610", "Mali-T830", "Mali-G52 MC2", "Mali-G71", "PowerVR Rogue GE8320", "Google SwiftShader").forEach { assertTrue(it, Quality3D.weakGpu(it)) }
        listOf("Adreno (TM) 650", "Adreno (TM) 730", "Mali-G78 MP14", "Mali-G610 MC6", "Immortalis-G715").forEach { assertFalse(it, Quality3D.weakGpu(it)) }
    }

    @Test fun theBackgroundComesOutAsItsColour() {
        val v = untonemapped(BG3D)
        val out = pbrNeutral(v)
        val want = floatArrayOf(srgbToLinear(0xF3 / 255f), srgbToLinear(0xF6 / 255f), srgbToLinear(0xFA / 255f))
        for (i in 0..2) assertEquals(want[i], out[i], 2e-3f)
    }

    @Test fun theToneCurveKeepsMidTones() {
        // PBR Neutral leaves colours under its knee alone (less a 0.04 toe)
        val c = floatArrayOf(.3f, .2f, .1f)
        val o = pbrNeutral(c)
        assertEquals(.26f, o[0], 1e-4f); assertEquals(.16f, o[1], 1e-4f); assertEquals(.06f, o[2], 1e-4f)
    }

    @Test fun theStudioLightIsSoftFromAboveAndWarm() {
        val sh = Studio.sh()
        assertEquals(27, sh.size)
        assertTrue(sh.all { it.isFinite() })
        // the constant term is positive in every channel; red a little above blue (warm walls and floor)
        assertTrue(sh[0] > 0 && sh[1] > 0 && sh[2] > 0 && sh[0] > sh[2])
        // more light from above than below (the ceiling and its strips over the floor): the y band is positive
        assertTrue(sh[3] > 0)
        // a window's light is several times a wall's
        assertTrue(Studio.radiance(0f, .05f, 1f)[0] > 3f * Studio.radiance(0f, 0f, -1f)[0])
    }
}
