class SwordPedestal extends StaticMeshActor
	implements( GGGrabbableActorInterface );

var HeroGoatComponent ownerComp;

var ParticleSystem mRepulsionParticleTemplate;
var ParticleSystem mSwordTakenParticleTemplate;

var SoundCue mRepulsionSound;
var SoundCue mSwordTakenSound;

var StaticMeshComponent pedestalMesh;
var StaticMeshComponent swordMesh;

var float repelForce;

var bool excaligoatTaken;

event PostBeginPlay()
{
	Super.PostBeginPlay();

	SetPhysics(PHYS_None);
}

function InitPedestal(HeroGoatComponent HGComp)
{
	ownerComp=HGComp;
}

function HideSword()
{
	swordMesh.SetHidden(true);
	swordMesh.SetActorCollision(false, false);
	swordMesh.SetBlockRigidBody(false);
	swordMesh.SetNotifyRigidBodyCollision(false);
}

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);
	//WorldInfo.Game.Broadcast(self, "TakeDamage : " $ damageCauser);
	RepelActor(damageCauser);
}

function RepelActor(Actor target)
{
	local GGPawn gpawn;
	local GGKactor kActor;
	local GGSVehicle vehicle;
	local float mass;
	local vector direction, newVelocity;
	local rotator rot;

	if(excaligoatTaken)
		return;

	direction = Normal(vect(1, 0, 1));
	rot.Yaw=Rotator(Normal(target.Location - Location)).Yaw;

	gpawn = GGPawn(target);
	kActor = GGKActor(target);
	vehicle = GGSVehicle(target);
	if(gpawn != none)
	{
		rot.Yaw=Rotator(Normal(gpawn.Mesh.GetPosition() - Location)).Yaw;
		gpawn.TakeDamage( 0.f, none, gpawn.Location, vect(0, 0, 0), class'GGDamageType');
		if(gpawn.mIsRagdoll)
		{
			newVelocity = gpawn.Mesh.GetRBLinearVelocity() + ((direction >> rot) * repelForce);
			gpawn.Mesh.SetRBLinearVelocity(newVelocity);
		}
		else
		{
			gpawn.AddVelocity((direction >> rot) * repelForce, gpawn.Location, class'GGDamageType');
		}
	}
	if(kActor != none)
	{
		mass=kActor.StaticMeshComponent.BodyInstance.GetBodyMass();
		//WorldInfo.Game.Broadcast(self, "Mass : " $ mass);
		kActor.ApplyImpulse((direction >> rot),  mass * repelForce,  -(direction >> rot));
	}
	else if(vehicle != none)
	{
		mass=vehicle.Mass;
		vehicle.AddForce((direction >> rot) * mass * repelForce);
	}
	else if(GGApexDestructibleActor(target) != none)
	{
		target.TakeDamage(10000000, none, target.Location, (direction >> rot) * mass * repelForce, class'GGDamageType');
	}

	PlaySound(mRepulsionSound,,,, Location);
	WorldInfo.MyEmitterPool.SpawnEmitter(mRepulsionParticleTemplate, Location, Rotator(Normal(vect(0, 0, 1))));
}


/*********************************************************************************************
 GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

function bool CanBeGrabbed( Actor grabbedByActor, optional name boneName = '' )
{
	return !excaligoatTaken;
}

function OnGrabbed( Actor grabbedByActor )
{
	if(!excaligoatTaken)
	{
		if(grabbedByActor == ownerComp.gMe)
		{
			ownerComp.ExcaligoatFound();
		}
		else
		{
			RepelActor(grabbedByActor);
		}
	}
}

function OnDropped( Actor droppedByActor );

function name GetGrabInfo( vector grabLocation, optional out vector out_BoneLocation, optional out PrimitiveComponent out_Comp )
{
	return '';
}

function PrimitiveComponent GetGrabbableComponent()
{
	return none;
}

function GGPhysicalMaterialProperty GetPhysProp()
{
	return none;
}

function SetNewMaterial( Material newMaterial );

function PrimitiveComponent GetMeshComponent();

/*********************************************************************************************
 END GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

function HeroSwordFound()
{
	WorldInfo.MyEmitterPool.SpawnEmitter(mSwordTakenParticleTemplate, Location);
	PlaySound(mSwordTakenSound,,,, Location);
	HideSword();
	excaligoatTaken=true;
	class'HeroSwordUnlocker'.static.UnlockHeroSword();
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false

	repelForce=1000.f

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Royal_Hall_01.Mesh.Pillar_Base_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Scale=0.2f
		Scale3D=(X=1.f, Y=1.f, Z=2.5f)
	End Object
	pedestalMesh=StaticMeshComp1
	Components.Add(StaticMeshComp1)

	Begin Object class=StaticMeshComponent Name=StaticMeshComp2
		StaticMesh=StaticMesh'MMO_Sword.Mesh.Sword'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
		CollideActors = true
        BlockActors = true
		Rotation=(Pitch=-16384, Yaw=0, Roll=0)
		Translation=(X=-11, Y=0, Z=100)
	End Object
	swordMesh=StaticMeshComp2
	Components.Add(StaticMeshComp2)

	CollisionComponent=StaticMeshComp1
	bCollideActors=true
	bBlockActors=true

	mRepulsionSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Excalibur_Explosion_Cue'
	mSwordTakenSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Level_Up_Cue'

	mRepulsionParticleTemplate=ParticleSystem'MMO_Effects.Effects.Effects_Xcalibur_01'
	mSwordTakenParticleTemplate=ParticleSystem'MMO_Effects.Effects.Effects_Levelup_01'
}