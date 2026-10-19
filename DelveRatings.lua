local _, addon = ...
-- User-supplied reference times and grades, not measured clear times.
-- Criteria IDs resolve Blizzard's localized story names; aliases cover known
-- naming discrepancies. Unverified stories deliberately have no criteria ID.
addon.DelveRatings = {
    { name = "The Gulf of Memory", levelingQuestID = 93416, zone = "Harandar", achievementID = 61731, stories = {
        { "Sporasaur Special", "0:44.01", "A", 220587 },
        { "Alnmoth Munchies", "1:52.34", "A", 220586 },
        { "Descent of the Haranir", "2:14.10", "C", 220585 },
    } },
    { name = "The Darkway", levelingQuestID = 93385, zone = "Quel'Thalas", achievementID = 61728, stories = {
        { "Ogre Powered", "1:03.24", "A", 220571 },
        { "Eggsplosive Growth", "1:28.41", "B" },
        { "Focusers Under Pressure", "1:43.81", "C", 220569 },
        { "Leyline Technician", "2:04.70", "C", 220570 },
    } },
    { name = "The Ring of Glory", zone = "The Coiled Isle", achievementID = 63436, stories = {
        { "Adopt-a-thon", "1:06.29", "A", 230518 },
        { "Game Day", "1:35.81", "A", 230517 },
        { "Open Night", "1:38.01", "A", 230516 },
    } },
    { name = "Parhelion Plaza", levelingQuestID = 93386, zone = "Quel'Thalas", achievementID = 61725, stories = {
        { "Holding the Line", "1:07.72", "A", 220601 },
        { "Caustic Crush", "2:04.77", "C", 230850 },
        { "March of the Arcane Brigade", "2:46.21", "D", 220602 },
        { "Bombing Run", "3:06.51", "B", 220603 },
    } },
    { name = "Collegiate Calamity", levelingQuestID = 93384, zone = "Quel'Thalas", achievementID = 61726, stories = {
        { "Invasive Glow", "1:13.22", "S", 220589 },
        { "Academy Under Siege", "1:29.37", "S", 220590 },
        { "Faculty of Fear", "1:49.02", "C", 220591 },
        { "An Elementary Antidote", "1:56.90", "C", 230848, aliases = { "An Elementary Anditode", "Academic Antitoxin" } },
    } },
    { name = "Twilight Crypts", levelingQuestID = 93410, zone = "Zul'Aman", achievementID = 61730, stories = {
        { "Party Crasher", "1:27.81", "B", 220573 },
        { "Trapped!", "1:41.16", "B", 220574 },
        { "Loosed Loa", "1:58.92", "C", 220575 },
        { "Why'd it Have to Be Snakes?", "2:09.17", "C", 230852, aliases = { "Why Did it Have to Be Snakes?" } },
    } },
    { name = "Sunkiller Sanctum", levelingQuestID = 93427, zone = "Voidstorm", achievementID = 61732, stories = {
        { "Core of the Problem", "1:29.66", "B", 220597 },
        { "Not What I Expected", "1:49.11", "C", 220599 },
        { "The Gravitational Effect", "2:31.52", "A", 220598 },
    } },
    { name = "Atal'Aman", levelingQuestID = 93409, zone = "Zul'Aman", achievementID = 61729, stories = {
        { "Toadly Unbecoming", "1:32.41", "A", 220583 },
        { "Venomous Vapors", "1:46.18", "B", 230851 },
        { "Totem Annihilation", "1:46.19", "A", 220581 },
        { "Ritual Interrupted", "1:57.75", "A", 220582 },
    } },
    { name = "The Shadow Enclave", levelingQuestID = 93372, zone = "Quel'Thalas", achievementID = 61727, stories = {
        { "Traitor's Due", "1:32.89", "A", 220577 },
        { "Mirror Shine", "2:02.17", "D", 220579 },
        { "Shadowy Supplies", "2:07.19", "A", 220578 },
        { "Infiltrate and Ameliorate", "2:41.67", "D", 230849, aliases = { "Basilisk Blitz" } },
    } },
    { name = "Shadowguard Point", levelingQuestID = 93428, zone = "Voidstorm", achievementID = 61733, stories = {
        { "Calamitous", "1:44.91", "S", 220594 },
        { "Basilisk Blitz", "1:58.16", "C", 230854, aliases = { "Basalisk Blitz" } },
        { "Captured Wildlife", "2:16.98", "C", 220595 },
        { "Stolen Mana", "3:31.77", "D", 220593 },
    } },
    { name = "The Grudge Pit", levelingQuestID = 93421, zone = "Harandar", achievementID = 61724, stories = {
        { "Arena Champion", "1:47.51", "B", 220566 },
        { "Dastardly Rotstalk", "2:19.62", "C", 220565 },
        { "Lightbloom Invasion", "2:26.19", "C", 220567 },
        { "Fungal Pharmacon", "4:09.11", "D", 230853 },
    } },
    { name = "Gnarldor Isle", zone = "The Coiled Isle", achievementID = 63437, stories = {
        { "Speaking Their Language", "2:21.50", "B", 230514 },
        { "Olds and Ends", "2:37.45", "D", 230512 },
        { "Minchi's Osseous Adventure", "2:44.50", "D", 230513 },
    } },
}
