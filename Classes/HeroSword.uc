class HeroSword extends Actor;

var ParticleSystemComponent mTrailParticle;
var ParticleSystemComponent mChargeParticle;

var SoundCue mAttackSound;
var SoundCue mTornadoCargeSound;
var SoundCue mTornadoSound;
var SoundCue mSwordBlockedSound;
var AudioComponent mAC;

var StaticMeshComponent swordMesh;
var StaticMeshComponent normalSwordMesh;
var StaticMeshComponent excaligoatMesh;

var float swordForce;
var bool isDoingSwing;
var bool isDoingTornado;

var array<Actor> hitActors;
var float swordRadius;

event PostBeginPlay()
{
	Super.PostBeginPlay();

	SetPhysics(PHYS_None);
	AttachComponent(mTrailParticle);
	AttachComponent(mChargeParticle);
	swordMesh=normalSwordMesh;
	normalSwordMesh.SetLightEnvironment( GGGoat(Owner).mesh.LightEnvironment );
	excaligoatMesh.SetLightEnvironment( GGGoat(Owner).mesh.LightEnvironment );
	excaligoatMesh.SetHidden(true);
	excaligoatMesh.SetActorCollision(false, false);
	excaligoatMesh.SetBlockRigidBody(false);
	excaligoatMesh.SetNotifyRigidBodyCollision(false);
}

function ShowSword()
{
	SetHidden(false);
	SetCollision(true, true);
	SetCollisionType(COLLIDE_BlockAll);
	CollisionComponent.SetActorCollision(true, true);
	CollisionComponent.SetBlockRigidBody(true);
	CollisionComponent.SetNotifyRigidBodyCollision(true);
}

function HideSword(optional bool hideEffects = true)
{
	SetHidden(true);
	SetCollision(false, false);
	SetCollisionType(COLLIDE_NoCollision);
	CollisionComponent.SetActorCollision(false, false);
	CollisionComponent.SetBlockRigidBody(false);
	CollisionComponent.SetNotifyRigidBodyCollision(false);
	isDoingSwing=false;
	isDoingTornado=false;
	if(mTrailParticle.bIsActive && hideEffects)
	{
		mTrailParticle.DeactivateSystem();
	}
	if(mChargeParticle.bIsActive)
	{
		mChargeParticle.DeactivateSystem();
		mChargeParticle.KillParticlesForced();
	}
	if(IsTimerActive(NameOf(ShowTornadoChargedParticles)))
	{
		ClearTimer(NameOf(ShowTornadoChargedParticles));
	}
	hitActors.Length=0;
}

function SetSwordTranslation(float radius)
{
	local vector newTrans;

	newTrans=swordMesh.default.Translation;
	newTrans.X = newTrans.X + radius;
	swordMesh.SetTranslation(newTrans);

	newTrans=mTrailParticle.default.Translation;
	newTrans.X = newTrans.X + radius;
	mTrailParticle.SetTranslation(newTrans);

	newTrans=mChargeParticle.default.Translation;
	newTrans.X = newTrans.X + radius;
	mChargeParticle.SetTranslation(newTrans);
}

function TornadoCharged()
{
	SetTimer(0.3f, false, NameOf(ShowTornadoChargedParticles));
	if( mAC == none || mAC.IsPendingKill() )
	{
		mAC = CreateAudioComponent( mTornadoCargeSound, false );
		mAC.HighFrequencyGainMultiplier = 2.f;
		mAC.PitchMultiplier = 2.f;
	}
	if( mAC.IsPlaying() )
	{
		mAC.Stop();
	}
	mAC.Play();
}

function ShowTornadoChargedParticles()
{
	mChargeParticle.ActivateSystem();
}

function Swing()
{
	if(isDoingTornado)
	{
		PlaySound(mTornadoSound,,,, Location);
	}
	else
	{
		PlaySound(mAttackSound,,,, Location);
		isDoingSwing=true;
	}
	mTrailParticle.ActivateSystem();
}

function EndSwing()
{
	if(mTrailParticle.bIsActive)
	{
		mTrailParticle.DeactivateSystem();
	}
	isDoingSwing=false;
	hitActors.Length=0;
}

function bool shouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return (
	act == none
	|| Volume(act) != none
	|| act == self
	|| act == Owner
	|| LaserSword(act) != none
	|| hitActors.Find(act) != -1);
}

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);

	//WorldInfo.Game.Broadcast(self, "TakeDamage");
	if(shouldIgnoreActor(damageCauser) || (!isDoingSwing && !isDoingTornado))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "TakeDamage=" $ damageCauser);
	ApplySwordDamages(damageCauser);
}

event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
    super.Bump(Other, OtherComp, HitNormal);
	//WorldInfo.Game.Broadcast(self, "Bump");
	if(shouldIgnoreActor(other) || (!isDoingSwing && !isDoingTornado))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "Bump=" $ other);
	ApplySwordDamages(other);
}

event RigidBodyCollision(PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent, const out CollisionImpactData RigidCollisionData, int ContactIndex)
{
	super.RigidBodyCollision(HitComponent, OtherComponent, RigidCollisionData, ContactIndex);
	//WorldInfo.Game.Broadcast(self, "RBCollision");
	if(shouldIgnoreActor(OtherComponent.Owner) || (!isDoingSwing && !isDoingTornado))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "RBCollision=" $ OtherComponent.Owner);
	ApplySwordDamages(OtherComponent!=none?OtherComponent.Owner:none);
}

function bool FindExtraTargets()
{
	local float distance;
	local Actor currTarget;
	local vector traceStart, targetPos, n;

	//traceStart=Location + (swordMesh.Translation >> Rotation);
	//DrawDebugLine (traceStart, traceStart + (Normal(vector(Rotation)) * swordRadius), 0, 0, 0,);

	if(!isDoingSwing && !isDoingTornado)
	{
		return true;
	}

	traceStart=Location + (swordMesh.Translation >> Rotation);
	//WorldInfo.Game.Broadcast(self, "FindExtraTargets() swordRadius=" $ swordRadius);

	foreach OverlappingActors( class'Actor', currTarget, swordRadius, traceStart)
    {
		if(shouldIgnoreActor(currTarget))
		{
			//WorldInfo.Game.Broadcast(self, "Ignored Extra Target :" $ currTarget);
			continue;
		}

		targetPos = currTarget.Location;
		if(GGPawn(currTarget) != none)
		{
			targetPos = GGPawn(currTarget).Mesh.GetPosition();
		}
		n = Normal(Vector(Rotation)) cross vect(0, 0, 1);
		distance = Abs((targetPos - Location) dot n)/VSize(n);

		//WorldInfo.Game.Broadcast(self, "Distance to" @ currTarget @ "is" @ distance);
		if(distance < 15.f)
		{
			//Shields block sword attacks
			if(HeroShield(currTarget) != none)
			{
				//WorldInfo.Game.Broadcast(self, "Shield Detected");
				PlaySound(mSwordBlockedSound,,,, Location);
				return false;
			}

			//WorldInfo.Game.Broadcast(self, "Found Extra Target :" $ currTarget);
			ApplySwordDamages(currTarget);
		}
    }

	return true;
}

function ApplySwordDamages(Actor target)
{
	local GGPawn gpawn;
	local GGNPCMMOEnemy mmoEnemy;
	local GGNpcZombieGameModeAbstract zombieEnemy;
	local GGKactor kActor;
	local GGSVehicle vehicle;
	local float mass, force;
	local vector direction, newVelocity;
	local int damage;

	hitActors.AddItem(target);

	direction = Normal(Vector(Rotation));
	force = isDoingTornado?swordForce*2.f:swordForce;

	gpawn = GGPawn(target);
	mmoEnemy = GGNPCMMOEnemy(target);
	zombieEnemy = GGNpcZombieGameModeAbstract(target);
	kActor = GGKActor(target);
	vehicle = GGSVehicle(target);
	if(gpawn != none)
	{
		mass=50.f;
		if(!gpawn.mIsRagdoll)
		{
			gpawn.SetRagdoll(true);
		}
		newVelocity = gpawn.Mesh.GetRBLinearVelocity() + (direction * force);
		gpawn.Mesh.SetRBLinearVelocity(newVelocity);
		//Damage MMO enemies
		if(mmoEnemy != none)
		{
			damage = int(RandRange(10, 30));
			if(isDoingTornado) damage *= 2;
			if(swordMesh == excaligoatMesh) damage *= 2;
			mmoEnemy.TakeDamageFrom(damage, Owner, class'GGDamageTypeExplosiveActor');
		}
		else
		{
			gpawn.TakeDamage( 0.f, GGGoat(Owner).Controller, gpawn.Location, vect(0, 0, 0), class'GGDamageType',, Owner);
		}
		//Damage zombies
		if(zombieEnemy != none)
		{
			damage = int(RandRange(10, 30));
			if(isDoingTornado) damage *= 2;
			if(swordMesh == excaligoatMesh) damage *= 2;
			zombieEnemy.TakeDamage(damage, GGGoat(Owner).Controller, zombieEnemy.Location, vect(0, 0, 0), class'GGDamageTypeZombieSurvivalMode' );
		}
	}
	if(kActor != none)
	{
		mass=kActor.StaticMeshComponent.BodyInstance.GetBodyMass();
		//WorldInfo.Game.Broadcast(self, "Mass : " $ mass);
		kActor.ApplyImpulse(direction,  mass * force,  -direction);
	}
	else if(vehicle != none)
	{
		mass=vehicle.Mass;
		vehicle.AddForce(direction * mass * force);
	}
	else if(GGApexDestructibleActor(target) != none)
	{
		target.TakeDamage(10000000, GGGoat(Owner).Controller, target.Location, direction * mass * force, class'GGDamageTypeAbility',, Owner);
	}
}

function UnlockExcaligoat()
{
	swordMesh.SetHidden(true);
	swordMesh.SetActorCollision(false, false);
	swordMesh.SetBlockRigidBody(false);
	swordMesh.SetNotifyRigidBodyCollision(false);
	swordMesh=excaligoatMesh;
	CollisionComponent=excaligoatMesh;
	swordMesh.SetHidden(false);
	swordForce=2000.f;
}

simulated event Tick( float delta )
{
	local GGPawn gpawn;
	// Try to prevent pawns from walking on it
	foreach BasedActors(class'GGPawn', gpawn)
	{
		gpawn.Velocity.Z=0;
		gpawn.SetRagdoll(true);
		gpawn.Velocity.Z=0;
	}

	super.Tick( delta );
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true
	mBlockCamera=false

	swordForce=1000.f
	swordRadius=100.0f

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'MMO_Characters.Mesh.Sword_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Rotation=(Pitch=16384, Yaw=0, Roll=0)
		Translation=(X=50, Y=0, Z=0)
	End Object
	normalSwordMesh=StaticMeshComp1
	Components.Add(StaticMeshComp1)

	Begin Object class=StaticMeshComponent Name=StaticMeshComp2
		StaticMesh=StaticMesh'MMO_Sword.Mesh.Sword'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Translation=(X=90, Y=0, Z=-11)
	End Object
	excaligoatMesh=StaticMeshComp2
	Components.Add(StaticMeshComp2)
	CollisionComponent = StaticMeshComp1
	bCollideActors=true
	bBlockActors=true

	mAttackSound=SoundCue'Zombie_Weapon_Sounds.Drop.Weapon_Drop_Cue'
	mTornadoSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Warrior_Charge_Cue'
	mTornadoCargeSound=SoundCue'Zombie_HUD_Sounds.Zombie_HUD_HealthHunger_Fill50_Cue'
	mSwordBlockedSound=SoundCue'MMO_IMPACT_SOUND.Cue.IMP_MMO_Sword'

	Begin Object Class=ParticleSystemComponent Name=ParticleSystemComponent0
        Template=ParticleSystem'Zombie_Particles.Particles.Speedlines_2'
		Translation=(X=100, Y=0, Z=0)
		bAutoActivate=true
		bResetOnDetach=true
	End Object
	mTrailParticle=ParticleSystemComponent0

	Begin Object Class=ParticleSystemComponent Name=ParticleSystemComponent1
        Template=ParticleSystem'MMO_Effects.Effects.Effects_Glow_01'
		Translation=(X=100, Y=0, Z=0)
		bAutoActivate=true
		bResetOnDetach=true
	End Object
	mChargeParticle=ParticleSystemComponent1
}