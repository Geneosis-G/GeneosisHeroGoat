class HeroVision extends GGMutator
	config(Geneosis);

var array<GGGoat> HVGoats;
var config bool isHeroVisionUnlocked;
var PostProcessChain celShader;

/**
 * if the mutator should be selectable in the Custom Game Menu.
 */
static function bool IsUnlocked( optional out array<AchievementDetails> out_CachedAchievements )
{
	return default.isHeroVisionUnlocked;
}

/**
 * Unlock the mutator
 */
static function UnlockHeroVision()
{
	if(!default.isHeroVisionUnlocked)
	{
		PostJuice( "Unlocked Hero Vision" );
		default.isHeroVisionUnlocked=true;
		static.StaticSaveConfig();
	}
}

function static PostJuice( string text )
{
	local GGGameInfo GGGI;
	local GGPlayerControllerGame GGPCG;
	local GGHUD localHUD;

	GGGI = GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game );
	GGPCG = GGPlayerControllerGame( GGGI.GetALocalPlayerController() );

	localHUD = GGHUD( GGPCG.myHUD );

	if( localHUD != none && localHUD.mHUDMovie != none )
	{
		localHUD.mHUDMovie.AddJuice( text );
	}
}

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );

	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			if(!default.isHeroVisionUnlocked)
			{
				DisplayLockMessage();
			}
			else
			{
				HVGoats.AddItem(goat);
				ClearTimer(NameOf(InitVisionUnlockers));
				SetTimer(1.f, false, NameOf(InitVisionUnlockers));
			}
		}
	}
	
	super.ModifyPlayer( other );
}

function InitVisionUnlockers()
{
	local GGGoat goat;
	local GGLocalPlayer goatPlayer;
	// Activate hero vision for all players who want it
	foreach HVGoats(goat)
	{
		goatPlayer = GGLocalPlayer( PlayerController( goat.Controller ).Player );
		goatPlayer.RemoveAllPostProcessingChains();
		if( goatPlayer.InsertPostProcessingChain( celShader, -1, false ) )
		{
			goatPlayer.TouchPlayerPostProcessChain();
		}
	}
}

function DisplayLockMessage()
{
	ClearTimer(NameOf(DisplayLockMessage));
	WorldInfo.Game.Broadcast(self, "Hero Vision Locked :( Find the Hero Sword once without help from the faery to unlock it.");
	SetTimer(3.f, false, NameOf(DisplayLockMessage));
}

DefaultProperties
{
	celShader=PostProcessChain'GeneosisSobelEdge.GeneosisSobelEdgePPC'
}