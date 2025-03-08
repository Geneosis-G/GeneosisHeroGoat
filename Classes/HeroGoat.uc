class HeroGoat extends GGMutator;

var array< HeroGoatComponent > mComponents;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local HeroGoatComponent heroComp;

	super.ModifyPlayer( other );

	goat = GGGoat( other );
	if( goat != none )
	{
		heroComp=HeroGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'HeroGoatComponent', goat.mCachedSlotNr));
		//WorldInfo.Game.Broadcast(self, "ghostComp=" $ ghostComp);
		if(heroComp != none && mComponents.Find(heroComp) == INDEX_NONE)
		{
			mComponents.AddItem(heroComp);
		}
	}
}

simulated event Tick( float delta )
{
	local int i;

	for( i = 0; i < mComponents.Length; i++ )
	{
		mComponents[ i ].Tick( delta );
	}
	super.Tick( delta );
}

function UnlockHeroSwords(array<GGGoat> swordGoats)
{
	local HeroGoatComponent HGC;
	local GGGoat goat;
	local bool goatFound;

	foreach mComponents(HGC)
	{
		if(swordGoats.Length == 0)
		{
			break;
		}
		goatFound=false;
		foreach swordGoats(goat)
		{
			if(HGC.gMe == goat)
			{
				goatFound=true;
				break;
			}
		}
		if(goatFound)
		{
			HGC.ExcaligoatFound(true);
			swordGoats.RemoveItem(goat);
		}
	}
}

DefaultProperties
{
	mMutatorComponentClass=class'HeroGoatComponent'
}