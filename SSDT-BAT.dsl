// 200 lines for a SSDT is lowkey wild

DefinitionBlock ("", "SSDT", 2, "LRYAN", "BATX", 0x00000003)
{
    External (\_SB.PCI0.LPCB.EC0, DeviceObj)
    External (\_SB.PCI0.LPCB.EC0.ACEX, IntObj)
    External (\_SB.PCI0.LPCB.EC0.BFCG, IntObj)
    External (\_SB.PCI0.LPCB.EC0.BTVO, IntObj)
    External (\_SB.PCI0.LPCB.EC0.BTRA, IntObj)
    External (\_SB.PCI0.LPCB.EC0.BAT0, DeviceObj)
    External (\_SB.PCI0.LPCB.EC0.ERAM, OpRegionObj)
    External (\_SB.PCI0.LPCB.EC0.BATT, IntObj)
    External (\_TZ.THRM, DeviceObj)
    External (\_SB.AC, DeviceObj)
    External (\_PR.CPU0, ProcessorObj) 
    
    Scope (\_SB.PCI0.LPCB.EC0)
    {
        Name (BCFG, Package ()
        {
            95,     // Maximum charge percentage
            90,     // Resume charge percentage
            3183,   // Maximum temperature (45°C)
            3083,   // Resume temperature (35°C)
            5497,   // Design capacity
            143,    // Initial cycle count
            300,    // Wait time after charge stop (seconds)
            15      // Power state transition delay (ms)
        })
        
        // Power states
        Name (PWST, Package ()
        {
            0,      // Battery power
            1,      // AC power, charging
            2,      // AC power, pass-through
            3       // Error state
        })
        
        // Current power state
        Name (CPST, 0)
        
        // Enhanced power state transition
        Method (PSTR, 2, Serialized)  // Args: Old State, New State
        {
            // Validate state transition
            If ((Arg0 != Arg1) && (Arg1 <= 3))
            {
                // Debug transition
                Debug = Package () {
                    "Power State Transition",
                    "From:", Arg0,
                    "To:", Arg1
                }
                
                // Transition delay
                Sleep (DerefOf(BCFG[7]))
                
                // Update state
                CPST = Arg1
                
                // Notify system of power change
                Notify (BAT0, 0x80)
                Notify (\_PR.CPU0, 0x80)  // Notify CPU of power change
                
                Return (One)
            }
            Return (Zero)
        }
        
        // Enhanced battery control with transitions
        Method (BCTL, 0, Serialized)
        {
            If (ACEX)  // On AC power
            {
                Local0 = BPCT()  // Battery percentage
                Local1 = BTMP()  // Temperature
                Local2 = BHTH()  // Health
                
                // Debug current status
                Debug = Package () {
                    "Status Check",
                    "Battery:", Local0,
                    "Temperature:", Local1,
                    "Health:", Local2,
                    "Current Power State:", CPST
                }
                
                // Determine appropriate power state
                If ((Local1 >= DerefOf(BCFG[2])) ||    // Over temperature
                    (Local0 >= DerefOf(BCFG[0])) ||    // Over percentage
                    (Local2 > 0))                      // Health warning
                {
                    If (BFCG)  // If currently charging
                    {
                        // Switch to pass-through power
                        PSTR (CPST, 2)  // Switch to AC pass-through
                        
                        // Additional safety checks for pass-through mode
                        If (CPST == 2)
                        {
                            // Verify pass-through is stable
                            Sleep (1000)
                            If (BFCG)  // Double-check charging is stopped
                            {
                                Debug = "Pass-through mode verified"
                            }
                        }
                    }
                }
                ElseIf (Local0 < DerefOf(BCFG[1]))  // Below resume threshold
                {
                    If (CPST == 2)  // If in pass-through
                    {
                        // Resume charging
                        PSTR (CPST, 1)  // Switch to charging mode
                    }
                }
            }
            Else  // On battery power
            {
                If (CPST != 0)  // If not already on battery
                {
                    PSTR (CPST, 0)  // Switch to battery power
                }
            }
        }
        
        // Enhanced event handlers with power state management
        Method (_Q04, 0, NotSerialized)  // AC Connected
        {
            Debug = "AC Connected"
            Sleep (100)  // Short stabilization delay
            BCTL()
        }
        
        Method (_Q05, 0, NotSerialized)  // AC Disconnected
        {
            Debug = "AC Disconnected"
            // Immediate transition to battery power
            PSTR (CPST, 0)
        }
        
        Method (_Q17, 0, NotSerialized)  // Battery Status
        {
            Debug = "Battery Status Change"
            BCTL()
        }
    }
}
