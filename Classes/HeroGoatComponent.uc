class HeroGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var bool isAttackPressed;
var bool isDefensePressed;

var bool isAttacking;
var bool isProtecting;

var bool isDoingSwing;
var float swordAngle;
var float swordSpeed;

var bool isTornadoReady;
var bool isDoingTornado;
var float tornadoChargeTime;

var HeroSword sword;
var HeroShield shield;
var SwordPedestal pedestal;

var float pedestalDist;

var StaticMeshComponent backSword;
var StaticMeshComponent backNormalSword;
var StaticMeshComponent backExcaligoat;
var StaticMeshComponent backShield;
var StaticMeshComponent backMirrorShield;

var bool useExcaligoat;
var bool canShootLasers;
var SoundCue mLaserSwordSound;
var AudioComponent mAC;

var bool isFaeryActive;
var float faeryActivationTime;
var float timeSinceLastTalk;
var SoundCue mFaerySound;
var ParticleSystemComponent mFaeryParticle;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	local vector pos;
	local rotator rot;

	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		backNormalSword.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( backNormalSword, 'jetPackSocket' );
		backExcaligoat.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( backExcaligoat, 'jetPackSocket' );
		backSword=backNormalSword;
		backExcaligoat.SetHidden(true);
		backShield.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( backShield, 'jetPackSocket' );
		backMirrorShield.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( backMirrorShield, 'jetPackSocket' );
		backMirrorShield.SetHidden(true);

		sword=gMe.Spawn(class'HeroSword', gMe,,,,, true);
		sword.HideSword();

		shield=gMe.Spawn(class'HeroShield', gMe,,,,, true);
		shield.HideShield();

		pos=GetPedestalPosition();
		rot.Yaw=Rotator(Normal(pos - gMe.Location)).Yaw;
		pedestal=gMe.Spawn(class'SwordPedestal',,, pos, rot,, true);
		pedestal.InitPedestal(self);

		gMe.mesh.AttachComponentToSocket( mFaeryParticle, 'Demonic' );
		mFaeryParticle.SetHidden(true);
	}
}

function vector GetPedestalPosition()
{
	local vector dest, center;
	local rotator rot;
	local float dist;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;
	local bool placedCorrectly;
	local int i, loops;

	center=gMe.Location;
	placedCorrectly=false;
	loops=0;// To avoid infinite loops
	while(!placedCorrectly && loops < 100)
	{
		rot=Rotator(vect(1, 0, 0));
		rot.Yaw+=RandRange(0.f, 65536.f);

		dist=RandRange(pedestalDist/2.f, pedestalDist);
		// Try to keep the distance and change only the angle if placement failed
		for(i=0 ; i<4 ; i++)
		{
			dest=center+Normal(Vector(rot))*dist;
			traceStart=dest;
			traceEnd=dest;
			traceStart.Z=10000.f;
			traceEnd.Z=-3000;

			hitActor = gMe.Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
			if( hitActor == none )
			{
				hitLocation = traceEnd;
			}

			if(hitActor != none && GGPawn(hitActor) == none && SwordPedestal(hitActor) == none)
			{
				placedCorrectly=true;
				break;
			}

			rot.Yaw+=16384;
		}
		loops++;
	}

	return hitLocation;
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if(localInput.IsKeyIsPressed("LeftMouseButton", string( newKey )) || newKey == 'XboxTypeS_RightTrigger')
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "LeftMouseButton pressed");
			isAttackPressed = true;
			StartAttacking();
		}
		if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey ))|| newKey == 'XboxTypeS_LeftTrigger')
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "RightMouseButton pressed";
			isDefensePressed = true;
			StartProtecting();
		}
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed("LeftMouseButton", string( newKey )) || newKey == 'XboxTypeS_RightTrigger')
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "LeftMouseButton released");
			isAttackPressed = false;
			if(!isDoingSwing)
			{
				if(isTornadoReady)
				{
					StartTornado();
				}
				else if(!isDoingTornado)
				{
					StopAttacking();
				}
			}
		}
		if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey )) || newKey == 'XboxTypeS_LeftTrigger')
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "RightMouseButton released");
			isDefensePressed = false;
			StopProtecting();
		}
	}
}

function StartAttacking()
{
	if(isDoingTornado || gMe.mIsRagdoll)
		return;

	if(isAttacking)
	{
		StopAttacking();
	}
	if(isProtecting)
	{
		StopProtecting();
	}

	isAttacking	= true;
	isDoingSwing = true;

	backSword.SetHidden(true);
	sword.ShowSword();
	sword.Swing();
	swordAngle = 8192;
}

function StopAttacking()
{
	if(!isAttacking)
		return;

	isAttacking	= false;
	isDoingSwing = false;
	isDoingTornado = false;
	isTornadoReady = false;

	backSword.SetHidden(false);
	sword.HideSword();
	swordAngle = 8192;

	if(gMe.IsTimerActive(NameOf(TornadoCharged), self))
	{
		gMe.ClearTimer(NameOf(TornadoCharged), self);
	}
	if(gMe.IsTimerActive(NameOf(DelayedStopAttacking), self))
	{
		sword.swordMesh.SetHidden(false);
		gMe.ClearTimer(NameOf(DelayedStopAttacking), self);
	}

	if(!isAttackPressed && isDefensePressed)
	{
		StartProtecting(true);
	}
}

function DelayedStopAttacking()
{
	StopAttacking();
	sword.swordMesh.SetHidden(false);
}

function StartProtecting(optional bool mute = false)
{
	if(isAttacking || gMe.mIsRagdoll)
		return;

	isProtecting = true;

	backShield.SetHidden(true);
	if(useExcaligoat)
	{
		backMirrorShield.SetHidden(true);
	}
	shield.ShowShield(mute);
}

function StopProtecting()
{
	if(!isProtecting)
		return;

	isProtecting = false;

	backShield.SetHidden(false);
	if(useExcaligoat)
	{
		backMirrorShield.SetHidden(false);
	}
	shield.HideShield();
}

function TornadoCharged()
{
	isTornadoReady = true;
	sword.TornadoCharged();
}

function StartTornado()
{
	isTornadoReady = false;
	isDoingTornado = true;
	sword.isDoingTornado = true;
	sword.Swing();
}

function Tick( float delta )
{
	local vector hVelocity, zVelocity;
	local float allowedHorizontalSpeed, allowedVerticalSpeed;

	ManageSword(delta);
	ManageShield();
	// When protecting your horizontal speed is limited (also vertical up speed is limited)
	if(isProtecting)
	{
		hVelocity = gMe.Velocity;
		hVelocity.Z=0;
		zVelocity.Z = gMe.Velocity.Z;
		allowedHorizontalSpeed = gMe.mWalkSpeed/2.f;
		allowedVerticalSpeed = allowedHorizontalSpeed * 2.f;
		if(zVelocity.Z > allowedVerticalSpeed)
		{
			zVelocity.Z = allowedVerticalSpeed;
		}
		if(VSize(hVelocity) > allowedHorizontalSpeed)
		{
			gMe.Velocity = (Normal(hVelocity) * allowedHorizontalSpeed) + zVelocity;
		}

	}
	// Don't use sword and shield when driving
	if(gMe.DrivenVehicle != none)
	{
		if(isAttacking)
		{
			isAttackPressed = false;
			StopAttacking();
		}
		if(isProtecting)
		{
			isDefensePressed = false;
			StopProtecting();
		}
	}
	// Activate faery if we stay ragdoll without moving for too long
	if(!isFaeryActive)
	{
		if(gMe.mIsRagdoll)
		{
			if(gMe.IsTimerActive(NameOf(ActivateFaery), self))
			{
				if(!IsZero(gMe.Velocity))
				{
					gMe.ClearTimer(NameOf(ActivateFaery), self);
				}
			}
			else
			{
				if(IsZero(gMe.Velocity))
				{
					gMe.SetTimer(faeryActivationTime, false, NameOf(ActivateFaery), self);
				}
			}
		}
	}
	// If faery is active, make it talk when we look in the direction of the sword pedestal
	else if(!useExcaligoat)// Stop talking if sword found
	{
		ManageFaerySound(delta);
	}
}

function ActivateFaery()
{
	if(!gMe.mIsRagdoll)
		return;

	isFaeryActive=true;
	mFaeryParticle.SetHidden(false);
}

function ManageFaerySound(float delta)
{
	timeSinceLastTalk = timeSinceLastTalk + delta;

	if(timeSinceLastTalk >= 2.f)
	{
		timeSinceLastTalk = timeSinceLastTalk - 2.f;

		if(IsGoatLookingToPedestal())
		{
			gMe.PlaySound(mFaerySound);
		}
	}
}

function bool IsGoatLookingToPedestal()
{
	local vector aFacing,aToB;

	aFacing=-Normal(Vector(gMe.Rotation));
	aToB=Normal(gMe.Location - pedestal.Location);

	return (Acos(aFacing dot aToB) < 0.78f);
}

function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	if(ragdolledActor == gMe)
	{
		if(isRagdoll)
		{
			StopAttacking();
			StopProtecting();
			if(useExcaligoat)
			{
				canShootLasers=false;
				if(gMe.IsTimerActive(NameOf(EnableLaserSwords), self))
				{
					gMe.ClearTimer(NameOf(EnableLaserSwords), self);
				}
			}
		}
		else
		{
			if(isDefensePressed)
			{
				StartProtecting();
			}
			if(useExcaligoat)
			{
				gMe.SetTimer(10.f, false, NameOf(EnableLaserSwords), self);
			}
		}
	}
}

function ManageSword(float delta)
{
	local rotator newRot;
	local float lastSwordAngle;
	// Do the swing attack
	if(isDoingSwing)
	{
		lastSwordAngle = swordAngle;
		swordAngle = swordAngle - (delta * swordSpeed);
		if(lastSwordAngle > 0 && swordAngle <= 0)
		{
			ShootLaserSword();
		}
		if(swordAngle <= -8192)
		{
			if(isAttackPressed)
			{
				isDoingSwing = false;
				sword.EndSwing();
				swordAngle = 0;
				gMe.SetTimer(tornadoChargeTime, false, NameOf(TornadoCharged), self);
			}
			else
			{
				StopAttacking();
			}
		}
	}
	// Do the tornado attack
	if(isDoingTornado)
	{
		swordAngle = swordAngle + (delta * swordSpeed * 1.5f);
		if(swordAngle >= 65536 + 8192)
		{
			if(isAttackPressed)
			{
				StopAttacking();
				StartAttacking();
			}
			else
			{
				// Delayed stop attack to show the effect completely
				isDoingTornado = false;
				sword.HideSword(false);
				sword.swordMesh.SetHidden(true);
				sword.SetHidden(false);
				backSword.SetHidden(false);
				gMe.SetTimer(0.5f, false, NameOf(DelayedStopAttacking), self);
			}
		}
	}

	newRot.Yaw = gMe.Rotation.Yaw + swordAngle;
	sword.SetRotation( newRot );

	sword.SetSwordTranslation(gMe.GetCollisionRadius());

	if(sword.Location != gMe.Location)
	{
		sword.SetLocation(gMe.Location);
		sword.SetBase(gMe);
	}

	if(!sword.FindExtraTargets())
	{
		StopAttacking();// If we hit the shield of another player
	}
}

function ManageShield()
{
	local vector camLocation;
	local rotator camRotation, newRot;

	if(gMe.Controller != none)
	{
		GGPlayerControllerGame( gMe.Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
	}
	else
	{
		camLocation=gMe.Location;
		camRotation=gMe.Rotation;
	}

	newRot.Yaw = camRotation.Yaw;
	shield.SetRotation( newRot );

	shield.SetShieldTranslation(gMe.GetCollisionRadius());

	if(shield.Location != gMe.Location)
	{
		shield.SetLocation(gMe.Location);
		shield.SetBase(gMe);
	}

	shield.FindApproachingProjectiles();
}

function ShootLaserSword()
{
	local vector dist, pos;
	local rotator rot;

	if(!canShootLasers)
		return;

	rot.Yaw=gMe.Rotation.Yaw;
	dist.X=gMe.GetCollisionRadius() + 120.f;
	pos = sword.Location + (dist >> rot);
	gMe.Spawn(class'LaserSword', gMe,, pos, rot,, true);
	if( mAC == none || mAC.IsPendingKill() )
	{
		mAC = gMe.CreateAudioComponent( mLaserSwordSound, false );
	}
	if( mAC.IsPlaying() )
	{
		mAC.Stop();
	}
	mAC.AdjustVolume(0.1f, 0.5f);
	mAC.Play();
}

function ExcaligoatFound(optional bool usedMutator=false)
{
	useExcaligoat=true;
	canShootLasers=true;
	pedestal.HeroSwordFound();
	StopAttacking();
	sword.UnlockExcaligoat();
	backSword.SetHidden(true);
	backSword=backExcaligoat;
	backSword.SetHidden(false);
	shield.UnlockMirrorShield();
	backMirrorShield.SetHidden(false);
	if(!usedMutator && !isFaeryActive)
	{
		class'HeroVision'.static.UnlockHeroVision();
	}
}

function EnableLaserSwords()
{
	canShootLasers=true;
}

defaultproperties
{
	swordSpeed=100000.f
	tornadoChargeTime=0.7f
	pedestalDist=10000.f
	faeryActivationTime=5.f

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'MMO_Characters.Mesh.Sword_01'
		Rotation=(Pitch=-16384, Yaw=0, Roll=0)
		Translation=(X=20, Y=0, Z=16)
	End Object
	backNormalSword=StaticMeshComp1

	Begin Object class=StaticMeshComponent Name=StaticMeshComp2
		StaticMesh=StaticMesh'MMO_Sword.Mesh.Sword'
		Rotation=(Pitch=0, Yaw=32767, Roll=0)
		Translation=(X=0, Y=0, Z=5)
	End Object
	backExcaligoat=StaticMeshComp2

	Begin Object class=StaticMeshComponent Name=StaticMeshComp3
		StaticMesh=StaticMesh'MMO_Props_02.Mesh.Props_Shield_01'
		Rotation=(Pitch=0, Yaw=-16384, Roll=16384)
		Translation=(X=-50, Y=0, Z=19)
	End Object
	backShield=StaticMeshComp3

	Begin Object class=StaticMeshComponent Name=StaticMeshComp4
		StaticMesh=StaticMesh'MMO_Props_02.Mesh.Props_Shield_01'
		Materials(0)=Material'Kitchen_01.Materials.Chrome_Mat_01'
		Rotation=(Pitch=0, Yaw=-16384, Roll=16384)
		Translation=(X=-46, Y=0, Z=21)
		Scale=0.9f
	End Object
	backMirrorShield=StaticMeshComp4

	Begin Object Class=ParticleSystemComponent Name=ParticleSystemComponent1
        Template=ParticleSystem'MMO_Effects.Effects.Effects_Friend_01'
	End Object
	mFaeryParticle=ParticleSystemComponent1
	mFaerySound=SoundCue'MMO_VO_SND.Cue.NPC_VO_Annoying_Kiwi_edition_Cue'
	mLaserSwordSound=SoundCue'Zombie_Weapon_Sounds.MindControl.MindControl_Blast_Cue'
}