<#
   posh-adventure 1.0.1
   Copyright (c) 2016 Chris Leclair
   An adventure game for bored sysadmins.
#>

<# PowerShell Version Warning #>

Write-Host "Found PowerShell version " -NoNewline
Write-Host $PSVersionTable.PSVersion.ToString()
if($PSVersionTable.PSVersion.Major -lt 5)
{
    Write-Host "posh-adventure is designed for PowerShell 5.0 or later"
    Write-Host "It may not work correctly on your system."
    Write-Host "Press ENTER to continue or CTRL-C to abort"
    Read-Host
}

Write-Host "Loading posh-adventure..."

<# Global Variables #>

# Be careful about variable scoping. Reference as $script:variable
# Most of these are self-explanatory
[boolean]$running = $FALSE
[string]$scene

# "stats"
[int]$hp
[int]$maxhp
[int]$level
[int]$atklevel
[int]$deflevel

# "inventory"
[int]$money
[int]$weaponlevel
[int]$armorlevel
[int]$potionamount
[System.Collections.ArrayList]$questitems

# fake constants, mostly for display
[System.Collections.ArrayList]$weaponnames = "None","Cane","Scimitar","Duelling Pistol","Waterfowl Shotgun"
[System.Collections.ArrayList]$armornames = "None","Vest","Maille","Cuirass","Suit of Armour"

<# Basic Functions #>

# Entry point called later- this is a bit of a hack but will prevent problems with the order in which functions are declared.
function main
{
    init

    loop

    quit
}

# Initialization function sets up when the game is started
function init
{
    Write-Host "Starting Posh-Adventure..."    

    #init params
    $script:hp = 100
    $script:level = 1
    
    $script:money = 100
    $script:potionamount = 1
    $script:armorlevel = 1
    $script:weaponlevel = 1
    $script:questitems = New-Object System.Collections.ArrayList

    CalculateStats

    $script:scene = "menu"
    $script:running = $TRUE
}

# Game main loop function
function loop
{
    #continue executing while game is running
    while($script:running -eq $TRUE)
    {
        # clear the screen
        Clear-Host

        # execute the current scene
        Invoke-Expression($script:scene)
    }
}

# Exit function cleans up
function quit
{
    Write-Host "Thanks for playing!"
}

<# Locations #>

# Pseudolocation: Character menu
function charmenu
{
    Clear-Host

    CalculateStats

    $weapon = $script:weaponnames[$script:weaponlevel]
    $armor = $script:armornames[$script:armorlevel]

    Write-Host "***** POSH-ADVENTURE *****"
    Write-Host "`n"

    Write-Host "Health:   $script:hp/$script:maxhp"
    Write-Host "Level:    $script:level"
    Write-Host "Attack:   $script:atklevel"
    Write-Host "Defence:  $script:deflevel"    

    Write-Host "`n"
    Write-Host "Remedies: $script:potionamount"
    Write-Host "Weapon: $weapon"
    Write-Host "Armour: $armor"
    Write-Host "`n"
    Write-Host "Quest Items:"
    foreach($item in $script:questitems)
    {
        if(-not $item.startsWith("!"))
        {
            Write-Host $item
        }
        
    }

    ReadKey

}

# Pseudolocation: combat
# $enemy should be a hashtable with name, hp, atk, and level
# also, this function leaks like a sieve
function battle([System.Collections.Hashtable]$enemy, [bool]$endbattle=$true, [bool]$canescape=$true)
{
    #force a recalculation of stats, just in case
    CalculateStats

    #create the player "object" (messy but works)
    [System.Collections.Hashtable]$player = @{"hp"=[ref]$script:hp;"maxhp"=[ref]$scipt:maxhp;"atk"=[ref]$script:atklevel;"def"=[ref]$script:deflevel;"potions"=[ref]$script:potionamount} #this is safe!
    
    # Write-Host $player.Get_Item("hp").value
    # $player.Get_Item("hp").value = 90
    # Write-Host $script:hp

    # battle variables
    [bool]$playerblocking | Out-Null #PowerShell's return semantics are retarded
    [bool]$enemyblocking | Out-Null #it was actually including these in the function return

    while($player.Get_Item("hp").value -gt 0 -and $enemy.Get_Item("hp") -gt 0)
    {
        
        #clear display
        Clear-Host

        #display header
        Write-Host -ForegroundColor Cyan "***** POSH-ADVENTURE *****" 
        Write-Host "You are engaged in combat with a " -NoNewline
        Write-Host $enemy.Get_Item("name") -ForegroundColor Red -NoNewline 
        Write-Host (" (" + $enemy.Get_Item("hp") + " hp)")
        Write-Host "Your health: " -NoNewline
        Write-Host ([string]$player.Get_Item("hp").value + " hp")
        Write-Host "`n"

        #display options
        Write-Host "You may " -NoNewline
        Write-Host "Attack" -ForegroundColor Magenta -NoNewline
        Write-Host ", " -NoNewline
        Write-Host "Block" -ForegroundColor Magenta -NoNewline
        if($player.Get_Item("potions").value -gt 0)
        {
            Write-Host ", " -NoNewline
            Write-Host "Heal" -ForegroundColor Magenta -NoNewline
            
        }
        if($canescape)
        {
            Write-Host ", " -NoNewline
            Write-Host "Run" -ForegroundColor Magenta
        }
        Write-Host "`n"        

        #prompt for input
        Write-Host "What action do you take?"
        $choice = Read-Host
        Write-Host "`n"

        #clear player blocking flag
        $playerblocking = $false

        #process input and act
        if($choice -eq "Attack")
        {                    
            if($enemyblocking)
            {                
                $damage = $player.Get_Item("atk").value * 4
            }
            else
            {
                $damage = $player.Get_Item("atk").value * 7
            }

            # random element
            $damage += [int](($damage / 10) * (Get-Random -Minimum -5 -Maximum 5))

            Write-Host "You strike your opponent with your weapon and deal $damage damage!"
            $enemy.Set_Item("hp", $enemy.Get_Item("hp") - $damage)
            
        }
        elseif($choice -eq "Block")
        {
            Write-Host "You brace yourself in preparation for an attack."
        }
        elseif($choice -eq "Heal" -and $player.Get_Item("potions").value -gt 0)
        {
            Write-Host "Utilizing a remedy, you heal 30 hp!" 
            $player.Get_Item("hp").value += 30 #hardcoded, may change
            $player.Get_Item("potions").value -= 1

        }
        elseif($choice -eq "Run" -and $canescape)
        {
            Write-Host "You hurriedly flee the battle."
            return $false
        }
        else
        {
            Write-Host "You are paralyzed by inaction!"
        }
        Write-Host "`n"

        #clear enemy blocking flag
        $enemyblocking = $false

        #check if enemy is dead
        if($enemy.Get_Item("hp") -le 0)
        {
            break
        }

        #enemy decides and acts
        $choicepercent = Get-Random -Maximum 100
        if($choicepercent -lt 70)
        {
            #70% chance of attacking
            $damage = $enemy.Get_Item("atk")
            $damage += ($damage / 12) * (Get-Random -Maximum 3)
            if($playerblocking)
            {
                $damage -= $damage / 3
            }
            $damage -= $player.Get_Item("def").value * 2
            # sanity fixes
            if($damage -le 0)
            {
                $damage = 1
            }
            $damage = [int]$damage

            Write-Host "Your opponent attacks for $damage damage!"

            $player.Get_Item("hp").value -= $damage
            
        }
        elseif($choicepercent -lt 90)
        {
            #20% chance of blocking
            Write-Host "Your opponent braces for an attack!"
            $enemyblocking = $false
        }
        else
        {
            #10% chance of doing nothing
            Write-Host "You opponent is paralyzed by inaction."
        }

        PromptKey

    }

    # battle is finished 
    if($endbattle)
    {
        if($player.Get_Item("hp").value -lt $enemy.Get_Item("hp"))
        {
            Write-Host "You have been defeated!"

            PromptKey

            #handle bad ending
            $script:scene = "gameover"
        }
        else
        {
            Write-Host "You have defeated your opponent!"

            PromptKey

            #level up
            $script:level += $enemy.Get_Item("level")

            #in the event of a victory, return true
            return $true
        }
    }
    else
    {
        if($player.Get_Item("hp").value -gt $enemy.Get_Item("hp"))
        {
            return $true
        }
        return $false

        #defer ending handling to the script above, return whether the battle was won or not
        return ($player.Get_Item("hp").value -gt $enemy.Get_Item("hp")) #a bit of a hack, returns true if player won
    }
    
}

# This displays the main menu 
function menu
{
    WriteCentered "Posh-Adventure" "Cyan"
    Write-Host "`n"
    WriteCentered "Of English gentlemen and bored sysadmins"

    Write-Host "`n"
    Write-Host "`n"
    Write-Host "`n"
    Write-Host "`n"
    WriteCentered "Press the any key to continue"
    WriteCentered "Press CTRL-C to quit"

    # wait for input
    ReadKey

    # set the scene to intro
    $script:scene = "intro"
}

# This displays the intro
function intro
{
    Write-Host "You are Sir Nigel Fawlett, a gentleman adventurer who resides in a castle in southern Mildenshire."
    Write-Host "Today is another glorious day in the Empire. You have spent the morning compiling an anthology of your travels."
    Write-Host "Yes, it has been a very productive day indeed."
    Write-Host "`n `n"

    PromptKey

    Clear-Host
    Write-Host "Peering through your monocle at your pocketwatch, you realize that it is nearly time for tea!"
    Write-Host "Not ordinary afternoon tea, heavens no! You have an appointment with Lord Trealey."
    Write-Host "He is quite an accomplished man and would not appreciate you dawdling."
    Write-Host "Time to get moving!"
    Write-Host "`n `n"

    PromptKey

    $script:scene = "office"
}

# This is the bad ending
function gameover
{
    Write-Host "You have failed in your noble endeavour."
    Write-Host "`n `n"
    Write-Host "Press the any key to quit"

    ReadKey

    $running = $false
}

# This is the good ending
function ending
{
    #TODO outro, credits, stinger

    if($script:questitems.Contains("!MarkerEndGood"))
    {
        # good ending
        Write-Host "You sheathe your sword. Lord Trealey has paid the ultimate price for his transgressions."
        Write-Host "A very unfortunate turn of events, but the matter of honour has been settled."
        Write-Host "You vacate the premises. Perhaps tomorrow's tea will be more pleasant."
    }
    else
    {
        # bad ending
        Write-Host "Lord Trealey holds his rapier at your throat, pausing before he takes your life."
        Write-Host "However, the blade never pierces your skin. He draws it back and calls the matter settled."
        Write-Host "You vacate the premises. Perhaps tomorrow's tea will be more pleasant."
    }
    Write-Host "`n"
    PromptKey
    
    # credits
    Clear-Host

    WriteCentered "Posh-Adventure" "Cyan"
    Write-Host "`n"
    WriteCentered "Of English gentlemen and bored sysadmins"
    Write-Host "`n"
    WriteCentered "Written and directed by Chris Leclair (XCVG)"
    WriteCentered "Created with PowerShell 5.0 and PowerShell ISE"
    WriteCentered "Visit us at www.xcvgsystems.com!"

    Write-Host "`n"
    Write-Host "`n"
    PromptKey

    #stinger
    Clear-Host
    if($script:questitems.Contains("!MarkerEndGood"))
    {
        # good ending
        Write-Host "Your fiancee lies dead, his blood soaking the expensive rug."
        Write-Host "In one hand you take the Trealey family sword. In the other, your familiar M9 pistol."
    }
    else
    {
        # bad ending
        Write-Host "Your fiancee is splattered in another man's blood. He assures you the matter is settled."
        Write-Host "But the matter is not settled. You gently take the sword from his trembling hands."  
    }
    Write-Host "Sir Nigel will pay for what he has done."
    Write-Host "`n"
    Write-Host "`n"
    Write-Host "Posh-Adventure 2... coming soon?"

    PromptKey

    # persistent save?

    $script:running = $false
}

function office
{
    WriteHeader

    Write-Host "The study is dominated by a heavy mahogany desk. Your personal stationary sits atop it."
    Write-Host "Books of science and adventure fill bookcases lining the walls."
    Write-Host "A spiral staircase of deep maple leads down to the Great Hall."
    Write-Host "`n"
    Write-Host "1. Examine desk"
    Write-Host "2. Go to Great Hall"

    $choice = GetInput

    # Write-Host $choice       
    # Write-Host $choice.GetType().FullName

    if($choice -eq 1)
    {
        if($script:weaponlevel -ge 2)
        {
            Write-Host "You find nothing of interest."
        }
        else
        {            
            Write-Host "You find your scimitar on your desk."
            Write-Host "A relic from your travels in Arabia, it now serves only as a letter opener."
            Write-Host "You decide to take it with you, for old times' sake."

            $script:weaponlevel = 2
        }
        
        Read-Host

    }
    elseif($choice -eq 2)
    {
        $script:scene = "hall"
    }

}

function hall
{
    WriteHeader

    Write-Host "The Great Hall dominates your estate, a lavishly furnished room three rods by five rods."
    Write-Host "A grand table forms the centerpiece, complimented by ornate chandeliers and venerable portraits."
    Write-Host "Merely standing in the cavernous expanse imbues you with a sense of awe."
    Write-Host "`n"
    Write-Host "1. Go to Study"
    Write-Host "2. Go to Garden"

    $choice = GetInput

    if($choice -eq 1)
    {
        $script:scene = "office"
    }
    elseif($choice -eq 2)
    {
        $script:scene = "garden"
    }

}

function garden
{
    WriteHeader

    Write-Host "The garden surrounds your estate, itself a lavish construction suitable for an aristocrat such as yourself."
    Write-Host "A magnificant fountain is surrounded by fields of intensely coloured flowers."
    Write-Host "Tending to the garden is a lone weathered labourer."
    Write-Host "`n"
    Write-Host "1. Converse with labourer"
    Write-Host "2. Go to Hall"
    Write-Host "3. Go to Mildenshire"

    $choice = GetInput

    if($choice -eq 1)
    {
        if($script:level -lt 2)
        {
            Write-Host "The labourer dispenses an amount of pedestrian, yet surprisingly insightful advice."
            $script:level++;
        }
        else
        {
            Write-Host "The labourer dispenses an amount of pedestrian advice below your stature."
        }
        
        Read-Host

    }
    elseif($choice -eq 2)
    {
        $script:scene = "hall"
    }
    elseif($choice -eq 3)
    {
        $script:scene = "town"
    }

}

function town
{
    WriteHeader

    Write-Host "Mildenshire is a familiar town, though not a particularly pleasant one."
    Write-Host "Typical of the underclass, it is built poorly and severely undermaintained."
    Write-Host "A tavern of ill repute stands to one side of the square, a vendor of convenience on the other."
    Write-Host "A road leads south towards Castle Trealey."
    if($script:questitems.Contains("!MarkerCheckedRoad"))
    {
        Write-Host "An alley leads southeast from the square toward an unsavoury part of the town."
    }
    Write-Host "You wrinkle your nose instinctively at the sight."
    Write-Host "`n"
    Write-Host "1. Converse with peasantry"
    Write-Host "2. Patronize Tavern"
    Write-Host "3. Patronize Vendor"
    Write-Host "4. Go to Estate"
    Write-Host "5. Go to Road"
    if($script:questitems.Contains("!MarkerCheckedRoad"))
    {
        Write-Host "6. Go to Alley"
    }

    $choice = GetInput

    if($choice -eq 1)
    {
       Write-Host "A peasant says to you,"
       Write-Host -NoNewline "`""
       ($a = "What brings you to our village, Sir Nigel?", "Afternoon, gov'nor.", "Good afternoon, Sir Nigel.", "u fuckin wut m8?", "Be careful, or someone's gonna put a knife in your back.","Shame about Brexit, isn't it?", "Rule Britannia!" ) | Get-Random | Write-Host -NoNewline #the PowerShell way!
       Write-Host "`""

       Read-Host
    }
    elseif($choice -eq 2)
    {
        $script:scene = "tavern"
    }
    elseif($choice -eq 3)
    {
        $script:scene = "shop"
    }
    elseif($choice -eq 4)
    {
        $script:scene = "garden"
    }
    elseif($choice -eq 5)
    {
        $script:scene = "road"
    }
    elseif($choice -eq 6)
    {
        if($script:questitems.Contains("!MarkerCheckedRoad"))
        {
            $script:scene = "tenements"
        }
    }

}

function tavern
{
    WriteHeader

    Write-Host "The Red Lion is a venue of dubious repute intended for a class far below your own."
    Write-Host "The dregs of society sit at battered tables. The bartender eyes you warily."
    Write-Host "The stench of unwashed masses and cheap liquors pervades the atmosphere."
    Write-Host "`n"
    Write-Host "1. Converse with peasantry"
    Write-Host "2. Imbibe spirits (£10)"
    Write-Host "3. Imbibe nourishment (£10)"
    Write-Host "4. Exit establishment"

    $choice = GetInput

    if($choice -eq 1)
    {
       Write-Host "A patron says to you,"
       Write-Host -NoNewline "`""
       ($a = "Rule Britannia!", "Feck off mate!", "Blaaargh", "Put more stuff in the thing more stuff goes in", "Afternoon, sir.", "What are you doing here?" ) | Get-Random | Write-Host -NoNewline #the PowerShell way!
       Write-Host "`""

       Read-Host
    }
    elseif($choice -eq 2)
    {
        if($script:money -ge 10)
        {
            $script:money -= 10

            Write-Host "The bartender slides you a mug of frothy ale."
            Write-Host "The powerful spirits leave you feeling woozy."

            if($script:hp -gt 5) #won't kill you
            {
                $script:hp -= 5
            }
            
        }
        else
        {
            Write-Host "The funds on your person are insufficient to complete the transaction."
        }

        Read-Host
    }
    elseif($choice -eq 3)
    {
        if($script:money -ge 10)
        {
            $script:money -= 10

            Write-Host "The bartender slides you a tray of fish and chips."
            Write-Host "The greasy meal leaves you feeling disgusted yet satisfied."

            $script:hp += 25

            if($script:hp -gt $script:maxhp)
            {
                $script:hp = $script:maxhp
            }
        }
        else
        {
            Write-Host "The funds on your person are insufficient to complete the transaction."
        }

        Read-Host
    }   
    elseif($choice -eq 4)
    {
        $script:scene = "town"
    }       
}

function shop
{
    WriteHeader

    Write-Host "The Sainsburys is a quaint shop selling basic goods of all varieties."
    Write-Host ""
    Write-Host "It would not be your first or even third choice of vendor under normal circumstances."
    Write-Host "`n"
    Write-Host "1. Inquire with shopkeeper"
    Write-Host "2. Purchase Duelling Pistol (£50)"
    Write-Host "3. Purchase Cuirass (£50)"
    Write-Host "4. Purchase Remedy (£10)"
    Write-Host "5. Exit Establishment"

    $choice = GetInput

    if($choice -eq 1)
    {
       Write-Host "The shopkeeper says to you,"
       Write-Host -NoNewline "`""
       ($a = "Afternoon.", "No returns", "Buy something or get out.", "Pick it off the shelf." ) | Get-Random | Write-Host -NoNewline #the PowerShell way!
       Write-Host "`""

       Read-Host
    }
    elseif($choice -eq 2)
    {
        if($script:weaponlevel -lt 3)
        {
            if($script:money -ge 50)
            {
                $script:money -= 50

                Write-Host "The shopkeeper hisses, `"Alright, sure, I'll sell you a 'duelling pistol'.`""
                Write-Host "He twitches his neck briefly before handing over the weapon."

                $script:weaponlevel = 3
            }
            else
            {
                Write-Host "The funds on your person are insufficient to complete the transaction."
            }
        }
        else
        {
            Write-Host "The weapon offered has no advantage over your current weapon."
        }

        Read-Host
    }
    elseif($choice -eq 3)
    {
        if($script:armorlevel -lt 3)
        {
            if($script:money -ge 50)
            {
                $script:money -= 50

                Write-Host "The shopkeeper hisses, `"Alright, sure, I'll sell you a 'cuirass'.`""
                Write-Host "He twitches his neck briefly before handing over the armour."

                $script:armorlevel = 3
            }
            else
            {
                Write-Host "The funds on your person are insufficient to complete the transaction."
            }
        }
        else
        {
            Write-Host "The armour offered has no advantage over your current armour."
        }

        Read-Host
    }
    elseif($choice -eq 4)
    {
        if($script:money -ge 10)
        {
            $script:money -= 10

            Write-Host "The shopkeeper shrugs before handing you an oddly shaped remedy in exchange for you coinage."

            $script:potionamount += 1
        }
        else
        {
            Write-Host "The funds on your person are insufficient to complete the transaction."
        }

        Read-Host
    }      
    elseif($choice -eq 5)
    {
        $script:scene = "town"
    } 
}

function road
{
    # WriteHeader

    Write-Host "The road has been washed away by a flood during the night, leaving nought but rubble."
    Write-Host "In no circumstances could a carraige, horseless or otherwise, navigate the terrain."
    Write-Host "You must find another route to your destination."
    Write-Host "`n"
    $script:questitems.Add("!MarkerCheckedRoad") | Out-Null

    PromptKey

    $script:scene = "town"
}

function tenements
{
    WriteHeader

    Write-Host "The tenements are the worst part of Mildenshire, inhabited by the lowest of the low."
    Write-Host "Among the wreckage of carraiges and run-down buildings is a severely dilapitated hostel."
    Write-Host "The locals eye you with disdain and hostility. It is a very dangerous place."
    Write-Host "You desire to leave the area as quickly as possible."
    Write-Host "A bridge leads south toward Castle Trealey."
    Write-Host "`n"
    Write-Host "1. Converse with peasantry"
    Write-Host "2. Patronize Hostel"
    Write-Host "3. Go to Mildenshire"
    Write-Host "4. Go to Bridge"

    $choice = GetInput   

    if(($a = $true,$false,$false | Get-Random))
    {
        #~33% chance of getting jumped

        Write-Host "A highwayman of ill intent has set upon your person!"
        PromptKey

        if(battle(@{"hp" = 50; "atk" = 10; "level" = 1;"name" = "Highwayman"})) # check the stability of this, other calls were having problems
        {
            $script:money += 10
        }
                
    }
    else
    {
        if($choice -eq 1)
        {
            #reply or chance of a random fight
            if(($a = $true,$false | Get-Random))
            {
                #~50% chance of getting jumped
                Write-Host "The revolting peasant refuses to reply and instead attacks!"
                PromptKey

                if(battle(@{"hp" = 50; "atk" = 6; "level" = 1;"name" = "Peasant"}))
                {
                    $script:money += 5
                }
            }
            else
            {
                Write-Host "The peasant says to you,"
                Write-Host -NoNewline "`""
                ($a = "This is all your fault, your highness.", "Leave me be.", "Someone's gonna kill you here.", "Fuck off!", "Asshole." ) | Get-Random | Write-Host -NoNewline
                Write-Host "`""

                Read-Host
            }
        }
        elseif($choice -eq 2)
        {
            $script:scene = "hostel"
        }
        elseif($choice -eq 3)
        {
            $script:scene = "town"
        }
        elseif($choice -eq 4)
        {
            $script:scene = "bridge"
        }
    }

}

function hostel
{
    WriteHeader

    Write-Host "The hostel is a dwelling far below polite society, for those who have nothing else."
    Write-Host "The lobby is wholly unimpressive, lined with faded wallpaper and obliterated furniture."
    Write-Host "A few vagabonds mill about, muttering among themselves. They eye you warily."
    Write-Host "You feel entirely out of place standing here."
    Write-Host "`n"
    Write-Host "1. Converse with vagabonds"
    Write-Host "2. Rent a room for the night"
    Write-Host "3. Go to Tenements"
    if($script:questitems.Contains("RoomKey"))
    {
        Write-Host "4. Go to Room"
    }
    

    $choice = GetInput   

    if($choice -eq 1)
    {
        Write-Host "The vagabonds do not respond. It seems they are not interested in conversation."

        Read-Host
    }
    elseif($choice -eq 2)
    {
        Write-Host "Are you mad?"

        Read-Host
    }
    elseif($choice -eq 3)
    {
        $script:scene = "tenements"
    }
    elseif($choice -eq 4 -and $script:questitems.Contains("RoomKey"))
    {
        $script:scene = "room"
    }

}

function room
{
    # WriteHeader

    # you can only come here if you have the room key so we don't have to check that

    # pre-battle banter
    Write-Host "A large and ungainly man stands before you in the dilapidated room."
    Write-Host "He tells you rather impolitely that this is his room and that he wishes harm upon you."
    Write-Host "You realize that your only options are to engage in combat or retreat strategically."

    # choose to battle or not yet?    
    Write-Host "1. Retreat strategically"
    Write-Host "2. Engage in combat"

    $choice = GetInput   

    if($choice -eq 1)
    {
        $script:scene = "hostel"
    }
    elseif($choice -eq 2)
    {
        # battle
        if(battle(@{"hp" = 150; "atk" = 15; "level" = 2;"name" = "Occupant"}))
        {
            Clear-Host

            # battle was won
            $script:money += 50

            # post-battle scene
            Write-Host "With the undignified hulk eliminated, you are free to retrieve the elixer."
            Write-Host "You find the elixir in question, a white powder, in a sack beneath the mattress."
            
            # get drugs, lose key

            PromptKey

            $script:questitems.Add("VitalityPreparation")
            $script:questitems.Remove("RoomKey")
        }        

        # leave
        $script:scene = "hostel"
        
    }    
}

function bridge
{
    # WriteHeader

    #I know my logic here is crappy, so be it
    if($script:questitems.Contains("!MarkerGaveDrugs"))
    {
        # visiting after giving the drugs
        Write-Host "The hoodlums glare at you as you make your way across the bridge."

        PromptKey

        $script:scene = "boxburry"
    }
    elseif($script:questitems.Contains("VitalityPreparation"))
    {
        # have the drugs
        Write-Host "The unkempt man unsheathes his knife again."
        Write-Host "He asks if you have retrieved his elixir yet."
        Write-Host "You reply in the affirmative and hand it over."
        Write-Host "He thanks you rather sarcastically before allowing you to cross."

        PromptKey
        $script:scene = "boxburry"
        $script:questitems.Remove("VitalityPreparation")
        $script:questitems.Add("!MarkerGaveDrugs")
    }
    elseif($script:questitems.Contains("RoomKey"))
    {
        # have room key but don't have drugs yet
        Write-Host "The unkempt man unsheathes his knife again."
        Write-Host "He asks if you have retrieved his elixir yet."
        Write-Host "You reply in the negative."
        Write-Host "He tells you rather rudely to retrieve it."

        PromptKey
        $script:scene = "tenements"
    }
    else
    {
        # first visit
        Write-Host "The path across the bridge is blocked by carraiges and hoodlums. Several pistols are visible."
        Write-Host "You politely ask them if they would be so kind as to allow you to pass. A tall, unkempt man answers."
        Write-Host "He unsheathes a small knife and refuses your request in an exceedingly impolite fashion."
        Write-Host "You ask him if perhaps an exchange could be made for safe passage."
        Write-Host "He considers your offer for a moment before tossing a bronze key at you."
        Write-Host "He instructs you to return to the tenements and retrieve an elixir from the hostel."
        Write-Host "Seeing no choice, you agree to the man's request."

        PromptKey
        
        $script:questitems.Add("RoomKey")
        $script:scene = "tenements"

    }
    
}

function boxburry
{
    WriteHeader

    Write-Host "Boxburry is a very quaint village and mostly empty at this time of day."
    Write-Host "Lord Trealey manages his domain well and it is quiet and clean as usual."
    Write-Host "On a small rise overlooking the village sits Castle Trealey, your destination."
    Write-Host "`n"
    Write-Host "1. Go to Mildenshire"
    Write-Host "2. Go to Castle Trealey"

    $choice = GetInput

    if($choice -eq 1)
    {
        $script:scene = "tenements"
    }
    elseif($choice -eq 2)
    {
        $script:scene = "castle"
    }
}

function castle
{
    # long final conversation

    Write-Host "Lord Trealey, splendourous as always, greets you as you enter the castle."
    Write-Host "`"Ah, Sir Nigel! Excellent of you to join us, as always.`""
    Write-Host "As per the usual custom, you allow the nobleman to lead you to his parlour."

    Read-Host
    Clear-Host

    Write-Host "The parlour is as stately as usual, certainly befitting a man of Lord Trealey's status."
    Write-Host "However, the woman sitting in the far corner catches your attention."
    Write-Host "Her clothing is excruciatingly pedestrian and her demeanour equally so."
    Write-Host "She stands taller than yourself but without half the elegance."
    Write-Host "Clearly she is not of the peerage or even remotely respectable."

    Read-Host
    Clear-Host

    Write-Host "Lord Trealey smiles at the woman before turning back to you."
    Write-Host "`"Sir Nigel, this is Elizabeth Lynch, soon to be Lady Trealey.`""
    Write-Host ""

    Write-Host "1. Object immediately and strongly"
    Write-Host "2. Ask Lord Trealey for a quiet word"
    Write-Host "3. Engage in a duel for Lord Trealey's honour"

    $choice = GetInput

    Clear-Host

    if($choice -eq 1)
    {
        Write-Host "You tell Lord Trealey he must be mad if he intends to marry this woman."
        Write-Host "He motions for the peasant woman to leave before replying,"
        Write-Host "`"I feared you would not understand. I wish to marry for love, not for status."
        Write-Host "We must move with the times, not live in the past. The world-my world- has changed.`""

        Read-Host
    }
    elseif($choice -eq 2)
    {
        Write-Host "You ask Lord Trealey for a private conversation."
        Write-Host "He obliges, motioning for the woman to leave before you launch your tirade."
        Write-Host "Lord Trealey is clearly upset by your advice. He tells you,"
        Write-Host "`"You don't understand that the world has changed, have you? It's not about politics anymore."
        Write-Host "I met Lizbeth when I was in the Navy and it was love at first sight.`""

        Read-Host
    }
    #otherwise, just go to the duel

    Clear-Host

    Write-Host "There is only one solution to this grave dishonour. You draw your rapier."
    PromptKey

    Clear-Host #necessary?

    $battle = (battle @{"hp" = 250; "atk" = 20; "level" = 5;"name" = "Lord Trealey"} $false $false)
      

    if(([bool]($battle[-1])))
    {
        #battle was won

        $script:questitems.Add("!MarkerEndGood")
    }
    else
    {
        #battle was lost

    }

    Clear-Host
    PromptKey

    $script:scene = "ending"

}

<# Utility Functions #>

# Calculates the stats a player should have
function CalculateStats
{
    #hardcoded here, sorry
    $script:maxhp = 100 + ($script:level - 1) * 5
    $script:atklevel = $script:level + $script:weaponlevel
    $script:deflevel = $script:level + $script:armorlevel
}

# Writes the header with stats and stuff
function WriteHeader
{
    Write-Host -ForegroundColor Cyan "***** POSH-ADVENTURE *****" 
    Write-Host -ForegroundColor Cyan "£$script:money | $script:hp/$script:maxhp HP | Level $script:level | $script:potionamount Remedies | Location: " -NoNewline
    Write-Host -ForegroundColor Yellow "$script:scene"
    Write-Host -ForegroundColor DarkCyan "Type m to open the character menu"
    Write-Host "`n"

}

# Writes text in the console centered
function WriteCentered([String] $text, $color = $null)
{
    $width = [int](Get-Host).UI.RawUI.BufferSize.Width
    $twidth = [int]$text.Length
    $offset = ($width / 2) - ($twidth / 2)
    $otext = $text.PadLeft($offset + $twidth)

    if($color)
    {
        Write-Host $otext -ForegroundColor $color
    }        
    else
    {
        Write-Host $otext
    }

     
}

# Gets and parses input
function GetInput($allowmenu = $true)
{
    $in = Read-Host

    $output = ParseInput $in
    return $output
}

# Parses string input into a number and/or opens the menu if allowed
function ParseInput($in, $allowmenu = $true)
{
    #handle invocation of menu
    if($in -eq "m" -and $allowmenu -eq $true)
    {
        charmenu

        return -1
    }
    else
    {
        if(-not ($in -as [int]))
        {
            return -1
        }

        return ($in -as [int])
    }
}

# Because I'm lazy
function PromptKey
{
    Write-Host "Press the any key to continue..."
    ReadKey
}

# Reads any key input
function ReadKey
{

    # uncomment for use in the actual command interpreter
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $x

    # Read-Host # used in ISE
}

# This executes the actual program after everything is loaded (part of the declaration hack)

main