﻿#include "StandardRespawnCommand.as";
#include "Requirements.as";
#include "Requirements_Tech.as";
#include "ShopCommon.as";
#include "Descriptions.as";
#include "Hitters.as";
#include "FactionCommon.as";
#include "Survival_Structs.as";

void onInit(CBlob@ this)
{
	this.Tag("remote_storage");
	this.Tag("ignore extractor");

	this.Tag("upkeep building");
	this.set_u8("upkeep cap increase", 1);
	this.set_u8("upkeep cost", 0);

	this.set_TileType("background tile", CMap::tile_wood_back);

	this.getCurrentScript().tickFrequency = 30;

	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;
	this.set_Vec2f("nobuild extend", Vec2f(0.0f, 0.0f));

	this.set_bool("base_allow_alarm", false);
	AddIconToken("$str$", "StoreAll.png", Vec2f(16, 16), 0);

	this.addCommandID("sv_store");
	this.addCommandID("sv_hidemap");

	this.Tag("minimap_large");
	this.set_u8("minimap_index", 17);
	this.set_bool("minimap_hidden", false);

	// this.Tag("invincible");

	this.set_f32("capture_speed_modifier", 0.80f);

	this.set_Vec2f("travel button pos", Vec2f(0.5f, 1));

	// Respawning & class changing
	this.Tag("respawn");
	InitRespawnCommand(this);
	InitClasses(this);

	// Inventory
	this.Tag("change class store inventory");
	this.inventoryButtonPos = Vec2f(28, 0);

	// Fancy brick floor
	CMap@ map = getMap();
	Vec2f offset = this.getPosition() - Vec2f(this.getWidth() / 2, -this.getHeight() + 8);

	for (int i = 0; i < this.getWidth(); i++)
	{
		if (!map.isTileSolid(offset + Vec2f(i, 0))) map.server_SetTile(offset + Vec2f(i, 0), CMap::tile_wood);
	}

	// Upgrading stuff
	//this.set_Vec2f("shop offset", Vec2f(-12, 5));
	this.set_Vec2f("shop menu size", Vec2f(4, 2));
	this.set_string("shop description", "Upgrades & Repairs");
	this.set_u8("shop icon", 15);
	// this.Tag(SHOP_AUTOCLOSE);

	AddIconToken("$icon_upgrade$", "InteractionIcons.png", Vec2f(32, 32), 21);
	AddIconToken("$icon_repair$", "InteractionIcons.png", Vec2f(32, 32), 15);

	{
		ShopItem@ s = addShopItem(this, "Upgrade to a Fortress", "$icon_upgrade$", "fortress", "Upgrade to a more durable Fortress.\n\n+ Higher inventory capacity\n+ Extra durability\n+ Tunnel travel\n+ 1 Upkeep");
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", 500);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 250);
		AddRequirement(s.requirements, "coin", "", "Coins", 175);
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 2;

		s.spawnNothing = true;
	}
	{
		ShopItem@ s = addShopItem(this, "Repair", "$icon_repair$", "repair", "Repair this badly damaged building.\nRestores 5% of building's integrity.");	
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 50);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", 50);
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 2;

		s.spawnNothing = true;
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (this.getDistanceTo(caller) > 96.0f) return;
	if (caller.getTeamNum() == this.getTeamNum() && caller.isOverlapping(this))
	{
		CBitStream params;
		params.write_u16(caller.getNetworkID());
		CButton@ button = caller.CreateGenericButton("$change_class$", Vec2f(-12, 0.0f), this, buildSpawnMenu, "Change class");

		CInventory @inv = caller.getInventory();
		if(inv is null) return;

		//if(inv.getItemsCount() > 0)
		//{
		//	CButton@ buttonOwner = caller.CreateGenericButton(28, Vec2f(14, 5), this, this.getCommandID("sv_store"), "Store", params);
		//}

		CButton@ buttonOwner = caller.CreateGenericButton(this.get_bool("minimap_hidden") ? 23 : 27, Vec2f(6, -8), this, this.getCommandID("sv_hidemap"), "Toggle Map Icon", params);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	onRespawnCommand(this, cmd, params);

	if (cmd == this.getCommandID("shop made item"))
	{
		u16 caller, item;

		if(!params.saferead_netid(caller) || !params.saferead_netid(item)) return;

		string data = params.read_string();

		if (data == "fortress")
		{
			Vec2f pos = this.getPosition();
			u8 team = this.getTeamNum();

			this.Tag("upgrading");
			this.getSprite().PlaySound("/Construct.ogg");
			this.getSprite().getVars().gibbed = true;

			if (isServer())
			{
				CBlob@ newBlob = server_CreateBlobNoInit("fortress");
				newBlob.server_setTeamNum(team);
				newBlob.setPosition(pos);
				newBlob.Init();

				newBlob.set_string("base_name", this.get_string("base_name"));
				newBlob.set_string("new_camp_name", this.get_string("new_camp_name"));
				newBlob.set_string("numeric_camp_name", this.get_string("numeric_camp_name"));
				newBlob.Tag("need_sync");

				this.MoveInventoryTo(newBlob);
				this.server_Die();
			}
		}
		else if (data == "repair")
		{
			this.getSprite().PlaySound("/ConstructShort.ogg");

			f32 heal = this.getInitialHealth() * 0.05f;
			this.server_SetHealth(Maths::Min(this.getHealth() + heal, this.getInitialHealth()));
		}
	}
	else if (cmd == this.getCommandID("sv_hidemap"))
	{
		this.set_bool("minimap_hidden", !this.get_bool("minimap_hidden"));

		this.set_u8("minimap_index", this.get_bool("minimap_hidden") ? 17 : 25);
	}

	if (cmd == this.getCommandID("sv_store"))
	{
		CBlob@ caller = getBlobByNetworkID(params.read_u16());
		
		if (isServer() && caller !is null)
		{
			CInventory @inv = caller.getInventory();
			if (caller.getName() == "builder")
			{
				CBlob@ carried = caller.getCarriedBlob();
				if (carried !is null)
				{
					if (carried.hasTag("temp blob"))
					{
						carried.server_Die();
					}
				}
			}

			if (inv !is null)
			{
				while (inv.getItemsCount() > 0)
				{
					CBlob@ item = inv.getItem(0);
					if (!this.server_PutInInventory(item))
					{
						caller.server_PutInInventory(item);
						break;
					}
				}
			}
		}

		if (caller !is null && caller.isMyPlayer())
		{
			caller.ClearButtons();
			caller.ClearGridMenus();
		}
	}
}

bool isInventoryAccessible(CBlob@ this, CBlob@ forBlob)
{
	return (forBlob.getTeamNum() == this.getTeamNum() && forBlob.isOverlapping(this));
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (customData == Hitters::builder)
	{
		if (hitterBlob !is null)
		{
			if (hitterBlob.getName() == "peasant")
				damage *= 0.50;
			else if (hitterBlob.getName() == "builder")
				damage *= 0.75;
		}
	}
	if (customData == Hitters::explosion || customData == Hitters::drill)
		damage *= 5.0f;

	return damage;
}

void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu@ gridmenu)
{
	if (forBlob is null) return;
	if (forBlob.getControls() is null) return;
	Vec2f mscpos = forBlob.getControls().getMouseScreenPos(); 

	Vec2f MENU_POS = mscpos+Vec2f(-170,-72);
	CGridMenu@ sv = CreateGridMenu(MENU_POS, this, Vec2f(1, 1), "Store ");
	
	CBitStream params;
	params.write_u16(forBlob.getNetworkID());
	CGridButton@ store = sv.AddButton("$str$", "Store ", this.getCommandID("sv_store"), Vec2f(1, 1), params);
}