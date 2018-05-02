
#namespace sound;

/@
"Name: play_in_space( <alias> , <origin> )"
"Summary: Stop playing the the loop sound alias on an entity"
"Module: Sound"
"CallOn: Level"
"MandatoryArg: <alias> : Sound alias to play"
"MandatoryArg: <origin> : Origin of the sound"
"Example: sound::play_in_space( "siren", level.speaker.origin );"
@/
function play_in_space( alias, origin, master ) {}

function play_on_players( sound, team ) {}
