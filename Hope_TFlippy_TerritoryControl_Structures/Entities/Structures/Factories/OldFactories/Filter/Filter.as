// TrapBlock.as

#include "Hitters.as";
#include "MapFlags.as";
#include "MinableMatsCommon.as";

int openRecursion = 0;

void onInit(CBlob@ this)
{
	this.getSprite().SetZ(10);

	this.getShape().SetRotationsAllowed(false);
	this.getShape().AddPlatformDirection(Vec2f(0, -1), 45, false);
	this.set_bool("open", false);
	this.set_bool("reversed", false);
	this.addCommandID("reverse");
	this.Tag("place norotate");

	//block knight sword
	this.Tag("blocks sword");
	this.Tag("blocks water");

	this.set_TileType("background tile", CMap::tile_castle_back);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;

	this.Tag("ignore extractor");
	this.Tag("builder always hit");

	HarvestBlobMat[] mats = {};
	mats.push_back(HarvestBlobMat(50.0f, "mat_stone")); 
	mats.push_back(HarvestBlobMat(15.0f, "mat_wood"));
	this.set("minableMats", mats);
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	CSprite@ sprite = this.getSprite();
	if (sprite is null) return;

	sprite.getConsts().accurateLighting = true;

	if (!isStatic) return;

	Vec2f pos = this.getPosition();
	CMap@ map = this.getMap();

	for (int i = 0; i < 3; i++)
	{
		map.server_SetTile(Vec2f((pos.x - 8) + i * 8, pos.y), CMap::tile_castle_back);
	}

	this.getSprite().PlaySound("/build_door.ogg");
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > 96.0f) return;
	CBitStream params;

	if (this !is null)
	{
		CButton@ button = caller.CreateGenericButton(17, Vec2f(0, 3.0f), this, this.getCommandID("reverse"), "Reverse logic filter \nAlready reversed: " + this.get_bool("reversed"), params);
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	if (!this.get_bool("reversed") && blob.getPlayer() is null) 
		return !(this.hasBlob(blob.getName(), 0) || this.hasBlob(blob.getName(), 1));
	else if (this.get_bool("reversed") && blob.getPlayer() is null)
		return (this.hasBlob(blob.getName(), 0) || this.hasBlob(blob.getName(), 1));
	else return true;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("reverse"))
	{
		if (this !is null)
		{
			if (!this.get_bool("reversed"))
				this.set_bool("reversed", true);
			else
				this.set_bool("reversed", false);
			printf("" + this.get_bool("reversed"));
		}
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob is null || blob.hasTag("player")) return;

	if (Maths::Abs(blob.getVelocity().y) < 2.0f) blob.setVelocity(Vec2f(this.isFacingLeft() ? -1 : 1, -1.0f));
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}
/*

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	if (!this.get_bool("reversed"))
		return !(this.hasBlob(blob.getName(), 0) || !this.hasBlob(blob.getName(), 1));
	else
		return this.hasBlob(blob.getName(), 0) || this.hasBlob(blob.getName(), 1);
}*/