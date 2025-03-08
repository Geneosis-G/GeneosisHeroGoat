class HeroSwordUnlocker extends GGMutator
	config(Geneosis);

var array<GGGoat> swordGoats;
var config bool isHeroSwordUnlocked;

/**
 * if the mutator should be selectable in the Custom Game Menu.
 */
static function bool IsUnlocked( optional out array<AchievementDetails> out_CachedAchievements )
{
	return default.isHeroSwordUnlocked;
}

/**
 * Unlock the mutator
 */
static function UnlockHeroSword()
{
	if(!default.isHeroSwordUnlocked)
	{
		PostJuice( "Unlocked Hero Sword" );
		default.isHeroSwordUnlocked=true;
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
			if(!default.isHeroSwordUnlocked)
			{
				DisplayLockMessage();
			}
			else
			{
				swordGoats.AddItem(goat);
				ClearTimer(NameOf(InitSwordUnlockers));
				SetTimer(1.f, false, NameOf(InitSwordUnlockers));
			}
		}
	}
	
	super.ModifyPlayer( other );
}

function InitSwordUnlockers()
{
	local HeroGoat hero;
	
	//Find Hero Goat mutator
	foreach AllActors(class'HeroGoat', hero)
	{
		if(hero != none)
		{
			break;
		}
	}
	
	if(hero == none)
	{
		DisplayUnavailableMessage();
		return;
	}
	
	//Activate hero swords
	hero.UnlockHeroSwords(swordGoats);
}

function DisplayUnavailableMessage()
{
	WorldInfo.Game.Broadcast(self, "Hero Sword only works if combined with Hero Goat.");
	SetTimer(3.f, false, NameOf(DisplayUnavailableMessage));
}

function DisplayLockMessage()
{
	ClearTimer(NameOf(DisplayLockMessage));
	WorldInfo.Game.Broadcast(self, "Hero Sword Locked :( Find the Hero Sword once to unlock it.");
	SetTimer(3.f, false, NameOf(DisplayLockMessage));
}

DefaultProperties
{}