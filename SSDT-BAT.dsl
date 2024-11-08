DefinitionBlock ("", "SSDT", 2, "LRYAN", "BATX", 0x00000003)
{
    External (\_SB.PCI0.LPCB.EC0, DeviceObj)
    External (\_SB.PCI0.LPCB.EC0.ACEX, IntObj)
    External (\_SB.PCI0.LPCB.EC0.BFCG, IntObj)
    External (\_SB.PCI0.LPCB.EC0.BAT0, DeviceObj)
    External (\_SB.PCI0.LPCB.EC0.BAT0._BST, MethodObj)

    Scope (\_SB.PCI0.LPCB.EC0)
    {
        // Configuration for passthrough charging
        Name (BCFG, Package ()
        {
            95,     // Maximum charge percentage
            90,     // Resume charge percentage
            300     // Wait time after charge stop (seconds)
        })
        
        // Power states
        Name (PWST, Package ()
        {
            0,      // Battery power
            1,      // AC power, charging
            2       // AC power, pass-through
        })
        
        // Current power state
        Name (CPST, 0)
        
        // Battery control focused on passthrough
        Method (BCTL, 0, Serialized)
        {
            If (ACEX)  // On AC power
            {
                // Use _BST to get battery percentage
                Local0 = \_SB.PCI0.LPCB.EC0.BAT0._BST()[1]  // Battery percentage
                
                If (Local0 >= DerefOf(BCFG[0]))  // Over maximum percentage
                {
                    If (BFCG)  // If currently charging
                    {
                        CPST = 2  // Switch to pass-through
                        Sleep (DerefOf(BCFG[2]))  // Stabilization delay
                        Notify (BAT0, 0x80)
                    }
                }
                ElseIf (Local0 < DerefOf(BCFG[1]))  // Below resume threshold
                {
                    If (CPST == 2)  // If in pass-through
                    {
                        CPST = 1  // Resume charging
                        Notify (BAT0, 0x80)
                    }
                }
            }
            Else  // On battery power
            {
                CPST = 0  // Switch to battery power
                Notify (BAT0, 0x80)
            }
        }
        
        // Event handlers for AC plug/unplug
        Method (_Q04, 0, NotSerialized)  // AC Connected
        {
            Sleep (100)  // Short stabilization delay
            BCTL()
        }
        
        Method (_Q05, 0, NotSerialized)  // AC Disconnected
        {
            CPST = 0  // Switch to battery power
            Notify (BAT0, 0x80)
        }
        
        Method (_Q17, 0, NotSerialized)  // Battery Status
        {
            BCTL()
        }
    }
}
