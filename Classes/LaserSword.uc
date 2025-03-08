class LaserSword extends GGKActor;

var StaticMeshComponent swordMesh;

var float swordForce;
var float swordRadius;

var float laserSpeed;

simulated event PostBeginPlay()
{
	Super.PostBeginPlay();
	//WorldInfo.Game.Broadcast(self, "LaserSwordSpawned=" $ self);
	StaticMeshComponent.BodyInstance.CustomGravityFactor=0.f;
	CollisionComponent.WakeRigidBody();
	StaticMeshComponent.SetRBLinearVelocity(Normal(vector(Rotation)) * laserSpeed);
	// Dissapear after 10 seconds of flight
	SetTimer(10.f, false, NameOf(HitAndDissapear));
}

function bool shouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return (
	act == none
	|| Volume(act) != none
	|| Landscape(act) != none
	|| act == self
	|| act.Owner == Owner);
}

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);
	//WorldInfo.Game.Broadcast(self, "TakeDamage");
	if(shouldIgnoreActor(damageCauser))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "TakeDamage=" $ damageCauser);
	HitAndDissapear(damageCauser);
}

event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
    super.Bump(Other, OtherComp, HitNormal);
	//WorldInfo.Game.Broadcast(self, "Bump");
	if(shouldIgnoreActor(other))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "Bump=" $ other);
	HitAndDissapear(other);
}

event RigidBodyCollision(PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent, const out CollisionImpactData RigidCollisionData, int ContactIndex)
{
	super.RigidBodyCollision(HitComponent, OtherComponent, RigidCollisionData, ContactIndex);
	//WorldInfo.Game.Broadcast(self, "RBCollision");
	if(shouldIgnoreActor(OtherComponent.Owner))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "RBCollision=" $ OtherComponent.Owner);
	HitAndDissapear(OtherComponent!=none?OtherComponent.Owner:none);
}

function FindExtraTargets()
{
	local float distance;
	local Actor currTarget;
	local vector traceStart, targetPos, n;

	//traceStart=Location + (swordMesh.Translation >> Rotation);
	//DrawDebugLine (traceStart, traceStart + (Normal(vector(Rotation)) * swordRadius), 0, 0, 0,);

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
			if(HeroShield(currTarget) != none && HeroShield(currTarget).isMirrorShield)
			{
				HeroShield(currTarget).ReflectProjectile(self);
				return;
			}

			//WorldInfo.Game.Broadcast(self, "Found Extra Target :" $ currTarget);
			HitAndDissapear(currTarget);
		}
    }
}

function HitAndDissapear(optional Actor target=none)
{
	local GGPawn gpawn;
	local GGNPCMMOEnemy mmoEnemy;
	local GGNpcZombieGameModeAbstract zombieEnemy;
	local GGKactor kActor;
	local GGSVehicle vehicle;
	local float mass;
	local vector direction, newVelocity;
	local int damage;

	direction = Normal(Vector(Rotation));

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
		newVelocity = gpawn.Mesh.GetRBLinearVelocity() + (direction * swordForce);
		gpawn.Mesh.SetRBLinearVelocity(newVelocity);
		//Damage MMO enemies
		if(mmoEnemy != none)
		{
			damage = int(RandRange(10, 30));
			damage *= 2;
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
			damage *= 2;
			zombieEnemy.TakeDamage(damage, GGGoat(Owner).Controller, zombieEnemy.Location, vect(0, 0, 0), class'GGDamageTypeZombieSurvivalMode' );
		}
	}
	if(kActor != none)
	{
		mass=kActor.StaticMeshComponent.BodyInstance.GetBodyMass();
		//WorldInfo.Game.Broadcast(self, "Mass : " $ mass);
		kActor.ApplyImpulse(direction,  mass * swordForce,  -direction);
	}
	else if(vehicle != none)
	{
		mass=vehicle.Mass;
		vehicle.AddForce(direction * mass * swordForce);
	}
	else if(GGApexDestructibleActor(target) != none)
	{
		target.TakeDamage(10000000, GGGoat(Owner).Controller, target.Location, direction * mass * swordForce, class'GGDamageTypeAbility',, Owner);
		return;
	}

	//WorldInfo.Game.Broadcast(self, "LaserSwordDestroyedBy=" $ target);
	ShutDown();
	Destroy();
}

simulated event Tick( float delta )
{
	local GGPawn gpawn;
	local float currVelocity;
	// Try to prevent pawns from walking on it
	foreach BasedActors(class'GGPawn', gpawn)
	{
		HitAndDissapear(gpawn);
	}

	// Destroy the sword if it's too slow
	currVelocity=VSize(Velocity);
	if(currVelocity > 0.f)
	{
		if(currVelocity < laserSpeed / 2.f)
		{
			HitAndDissapear();
		}

		// Rotate the sword in the direction of its velocity
		StaticMeshComponent.SetRBRotation(rotator(Normal(Velocity)));
		// Maintain velocity
		if(currVelocity < laserSpeed)
		{
			StaticMeshComponent.SetRBLinearVelocity(Normal(vector(Rotation)) * laserSpeed);
		}
	}
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	mBlockCamera=false

	swordForce=1000.f
	swordRadius=100.0f
	laserSpeed=10000.f

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'MMO_Sword.Mesh.Sword'
		Materials(0)=Material'CaptureTheFlag.Materials.Red_Mat_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Translation=(X=90, Y=0, Z=-11)
	End Object
	swordMesh=StaticMeshComponent0

	bCollideActors=true
	bBlockActors=true
	bCollideWorld=true;
}