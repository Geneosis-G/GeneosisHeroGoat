class HeroShield extends Actor;

var StaticMeshComponent shieldMesh;
var SoundCue mShieldSound;
var float shieldRadius;
var bool isProtecting;

var bool isMirrorShield;
var StaticMeshComponent mirrorShieldMesh;
var SoundCue mMirrorSound;

event PostBeginPlay()
{
	Super.PostBeginPlay();

	SetPhysics(PHYS_None);
	shieldMesh.SetLightEnvironment( GGGoat(Owner).mesh.LightEnvironment );
	mirrorShieldMesh.SetLightEnvironment( GGGoat(Owner).mesh.LightEnvironment );
	mirrorShieldMesh.SetHidden(true);
	mirrorShieldMesh.SetActorCollision(false, false);
	mirrorShieldMesh.SetBlockRigidBody(false);
	mirrorShieldMesh.SetNotifyRigidBodyCollision(false);
}

function ShowShield(optional bool mute = false)
{
	SetHidden(false);
	SetCollision(true, true, false);
	SetCollisionType(COLLIDE_BlockAll);
	CollisionComponent.SetActorCollision(true, true);
	CollisionComponent.SetBlockRigidBody(true);
	CollisionComponent.SetNotifyRigidBodyCollision(true);
	if(!mute)
	{
		PlaySound(mShieldSound,,,, Location);
	}
	isProtecting=true;
}

function HideShield()
{
	SetHidden(true);
	SetCollision(false, false, true);
	SetCollisionType(COLLIDE_NoCollision);
	CollisionComponent.SetActorCollision(false, false);
	CollisionComponent.SetBlockRigidBody(false);
	CollisionComponent.SetNotifyRigidBodyCollision(false);
	isProtecting=false;
}

function SetShieldTranslation(float radius)
{
	local vector newTrans;

	newTrans=shieldMesh.default.Translation;
	newTrans.X = newTrans.X + radius;
	shieldMesh.SetTranslation(newTrans);

	newTrans=mirrorShieldMesh.default.Translation;
	newTrans.X = newTrans.X + radius;
	mirrorShieldMesh.SetTranslation(newTrans);
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

function UnlockMirrorShield()
{
	isMirrorShield=true;
	mirrorShieldMesh.SetHidden(false);
}
// Reflect laser swords
function FindApproachingProjectiles()
{
	local Actor currTarget;
	local vector traceStart;

	if(!isProtecting || !isMirrorShield)
		return;

	traceStart=Location + (shieldMesh.Translation >> Rotation);
	//WorldInfo.Game.Broadcast(self, "FindExtraTargets() swordRadius=" $ swordRadius);

	foreach OverlappingActors( class'Actor', currTarget, shieldRadius, traceStart)
    {
		if(LaserSword(currTarget) != none)
		{
			ReflectProjectileIfPossible(currTarget);
		}
    }
}
// Test if the projectile is on the right side of the shield and moving in the right direction
function bool CanBeReflected(Actor projectile)
{
	local vector aFacing, aToB, projPos;
	local GGPawn gpawnProj;

	if(!isProtecting || !isMirrorShield)
		return false;

	projPos=projectile.Location;
	gpawnProj=GGPawn(projectile);
	if(gpawnProj != none && gpawnProj.mIsRagdoll)
	{
		projPos=gpawnProj.Mesh.GetPosition();
	}

	// The projectile is behind the shield so ignore it
	aFacing=Normal(Vector(Rotation));
	aToB=projPos - Location;
	if(aFacing dot aToB <= 0.f)
	{
		return false;
	}
	// The projectile is not moving in the direction of the shield so ignore it
	aFacing=Normal(projectile.Velocity);
	aToB=Location - projPos;
	if(aFacing dot aToB <= 0.f)
	{
		return false;
	}

	return true;
}
// Reflect the projectile if the previous test is valid
function ReflectProjectileIfPossible(Actor projectile)
{
	if(CanBeReflected(projectile))
	{
		ReflectProjectile(projectile);
	}
}
// Reflect a projectile
function ReflectProjectile(Actor projectile)
{
	local vector shieldNormal;

	if(!isProtecting || !isMirrorShield)
		return;
	//WorldInfo.Game.Broadcast(self, "Reflect Projectile :" $ projectile);
	shieldNormal = Normal(vector(Rotation));
	//DrawDebugLine (projectile.Location, projectile.Location + projectile.Velocity, 0, 255, 0,);
	//DrawDebugLine (projectile.Location, projectile.Location + projectile.Velocity + shieldNormal * (projectile.Velocity dot shieldNormal) * -2, 0, 0, 255,);
	projectile.Velocity = projectile.Velocity + shieldNormal * (projectile.Velocity dot shieldNormal) * -2;
	GGKactor(projectile).StaticMeshComponent.SetRBLinearVelocity(projectile.Velocity + shieldNormal * (projectile.Velocity dot shieldNormal) * -2);
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true
	mBlockCamera=false

	shieldRadius=100.f

	mShieldSound=SoundCue'Zombie_Weapon_Sounds.Lovegun.Lovegun_Pickup_Cue'
	mMirrorSound=SoundCue'Goat_Sounds_Impact.Cue.Impact_MetalFurniture_Cue'

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'MMO_Props_02.Mesh.Props_Shield_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Rotation=(Pitch=0, Yaw=16384, Roll=0)
		Translation=(X=50, Y=0, Z=-10)
	End Object
	shieldMesh=StaticMeshComp1
	Components.Add(StaticMeshComp1)

	Begin Object class=StaticMeshComponent Name=StaticMeshComp2
		StaticMesh=StaticMesh'MMO_Props_02.Mesh.Props_Shield_01'
		Materials(0)=Material'Kitchen_01.Materials.Chrome_Mat_01'
		Rotation=(Pitch=0, Yaw=16384, Roll=0)
		Translation=(X=52, Y=0, Z=-6)
		Scale=0.9f
	End Object
	mirrorShieldMesh=StaticMeshComp2
	Components.Add(StaticMeshComp2)

	CollisionComponent = StaticMeshComp1
	bCollideActors=true
	bBlockActors=true
}