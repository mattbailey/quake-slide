/*******************************************\
*                                           *
* SLIDE: A crappy name for a cool 'lil game *
*                                           *
\*******************************************/

//This is Slide v1.1

//(c) Copyright 1997 By Nick "SiNGE" Bousman
//E-Mail: singe@ix.netcom.com

//Do not modify or distribute this code!
//I worked hard on it.

//New QC: camera.qc, slide.qc
//Modified QC: defs.qc, weapons.qc, client.qc, world.qc, combat.qc, player.qc

void() REAL_Comments =
{
   //These comments stay, even when decompiled
   bprint(" This is Slide version 1.1                                   ");
   bprint(" Slide is (C) Copyright 1997 By Nick 'SiNGE' Bousman          ");
   bprint(" E-mail: singe@ix.netcom.com                                  ");
   bprint("");
   bprint(" Do not modify or distribute this code!                       ");
   bprint(" I worked hard on it.                                         ");
   bprint("");
   bprint(" Oh, and if you decompiled this, you're a twit.               ");
};

void() W_SetCurrentAmmo;
void(vector org) spawn_tfog;
void() SUB_regen;
float() crandom;
void() player_trip1;
void() Spawn_ABoard;
void() Spawn_Board;
void() GlowOff;

//**************************************************************************
// SLIDER CONTROL
//**************************************************************************

//Collisions damage
void(entity attacker, entity targ) Impact =
{
   if (vlen(attacker.velocity - targ.velocity) < 300) return;
   if (!attacker.slide_on) return;
   if (targ.slide_on && (sflags & SF_INTERBASHNO)) return;

   local float dam;

   dam = vlen(attacker.velocity - targ.velocity) * 0.09;

   attacker.slide_on = 10;
   T_Damage(targ, attacker, attacker, dam);
   attacker.slide_on = 1;

   sound (attacker, CHAN_AUTO, "bland2.wav", 1, ATTN_NORM);
};

//Collisions with players and monsters.
void() Slide_Touch =
{
   if (other == world) return;
   if (other.takedamage != DAMAGE_AIM) return;

   local vector tempv;
   local float selfv, otherv;

   other.flags = other.flags-(other.flags&FL_ONGROUND);

   selfv = vlen(self.velocity);
   otherv = vlen(other.velocity);

   if (selfv > otherv)
      Impact(self, other);
   else
      Impact(other, self);

   tempv = self.velocity;
   self.velocity = other.velocity + '0 0 1';
   other.velocity = tempv;
};

//Board goes on
void() Slide_On =
{
   self.slide_on = 1;
   self.touch = Slide_Touch;

   self.attack_finished = time + 0.6;

   W_SetCurrentAmmo();
};

//Board goes on
void() Slide_Off =
{
   self.slide_on = 0;
   self.touch = SUB_Null;

   self.attack_finished = time + 0.6;

   W_SetCurrentAmmo();
};

//For landing sounds and perhaps bouncing basically. :)
void() CheckSlideGround =
{
   local float r;

   traceline(self.origin, self.origin - '0 0 45', TRUE, self);

   if (trace_fraction >= 1 && self.flags&FL_ONGROUND2)
      self.flags = self.flags - FL_ONGROUND2;

   if (trace_fraction < 1 && !(self.flags&FL_ONGROUND2))
   {
      //a landing

      self.flags = self.flags | FL_ONGROUND2;

      if (self.jump_flag < -1000)
      {
         sound (self, CHAN_BODY, "bland1.wav", 1, ATTN_NORM);

         if (self.jump_flag > -2000)
            r = rint(((0 - self.jump_flag) * 0.01));
         else
            r = 20;

         makevectors(self.angles);
         while (r > 0)
         {
            particle (self.origin + '0 0 -30' + v_forward*crandom()*20 + v_right*crandom()*20, v_forward*crandom()*20 + v_right*crandom()*20, 8, 40);
            r = r - 1;
         }

         return;
      }
      if (self.jump_flag < -200)
      {
         r = (0 - self.jump_flag) * 0.001;
         if (r > 1) r = 1;

         sound (self, CHAN_BODY, "bland2.wav", r, ATTN_NORM);
         return;
      }
   }

};

//The think function for when you're on a board
void() Slide_OnThink =
{
   CheckSlideGround();

   self.flags = self.flags-(self.flags&FL_ONGROUND);

   if (self.frame != 0) self.frame = 0;

   if (!(pointcontents(self.origin) == CONTENT_EMPTY))
   {
      if (pointcontents(self.origin) == CONTENT_LAVA)
      {
         Spawn_Board();
         Slide_Off();
         return;
      }
   }
};

//The artificial impulse toggle
void() Slide_Toggle =
{
   if (self.slide_on == 0)
   {
      sprint(self,"Slider Activated!\n");
      Slide_On();
   }
   else
   {
      sprint(self,"Slider Deactivated!\n");
      Slide_Off();
   }
};

//Jumping while on a hoverboard
void() Slide_Jump =
{
   traceline(self.origin, self.origin - '0 0 52', TRUE, self);

   if (trace_fraction >= 1) return;

   if (!(self.flags & FL_JUMPRELEASED))
      return;

   self.flags = self.flags-(self.flags&FL_JUMPRELEASED);

//   sound (self, CHAN_BODY, "doors/airdoor2.wav", 1, ATTN_NORM);
   sound (self, CHAN_BODY, "bjump1.wav", 1, ATTN_NORM);

   self.flags = self.flags-(self.flags&FL_ONGROUND);

   self.velocity = self.velocity + '0 0 300';
};

//The "turning" routine for when you're on your hoverboard
void() Slide_Turn =
{
   if (self.pushtime > time) return;
   self.pushtime = time + 0.1;

   local vector facing, moving;
   local float tempf;

   facing = self.angles;

   moving = vectoangles(self.velocity);

//Beginning of the actual routine to "average" two angles.
//THIS particular code finds finds the "inbetween" angle right of
// facing_y and moving_y. Angle math of two floating points I guess.

   moving_y = anglemod(moving_y);
   facing_y = anglemod(facing_y);

   tempf = fabs(moving_y - facing_y);

   if (fabs(moving_y - facing_y) > 180)
   {
      if (moving_y > 180) moving_y = moving_y - 360;
      if (facing_y > 180) facing_y = facing_y - 360;
   }
   moving_y = (moving_y + facing_y) * 0.5;

   moving_y = anglemod(moving_y);

//The angle moving_y is now halfway from what it was to where facing_y is;

   makevectors(moving);

   v_forward_z = 0-v_forward_z;

   self.velocity = v_forward * vlen(self.velocity);

//turning sound.
   if (!(self.flags&FL_ONGROUND2)) return;

   tempf = fabs(tempf);
   if (tempf > 10)
   {
      if ((tempf - 9) > 254) tempf = 254;

      particle(self.origin-'0 0 30', '0 0 0', 40, tempf - 9);

      tempf = 0.02 * tempf;
      if (tempf > 1) tempf = 1;

      sound (self, CHAN_VOICE, "board4.wav", tempf, ATTN_NORM);
   }
};

//Setammo for when you're on a board
void() Slide_SetAmmo =
{
   self.items = self.items-(self.items&(IT_SHELLS|IT_NAILS|IT_ROCKETS|IT_CELLS));

   self.currentammo = 1;
   self.weaponmodel = "";
   self.weaponframe = 0;
};

//Attack while on a board. Just calls another function.
void() Slide_Attack =
{
   Slide_Turn();

   return;
};

//Tiny push
void() Slide_Push =
{
   local float spd;

   spd = vlen(self.velocity);

   if (spd < 320)
   {
      self.velocity = normalize(self.velocity);
      self.velocity = self.velocity * 320;
   }
};

//The 1-8 impulse control while on a board
void() Slide_ChangeWeapon =
{
   if (self.impulse == 1)
   {
      sprint(self,"Slider Deactivated!\n");

      Spawn_ABoard();

      Slide_Off();
   }

//   if (self.impulse == 2)
//      Slide_Push();

   self.impulse = 0;
};

//**************************************************************************
// ITEMS
//**************************************************************************

void(entity targ, vector dir, float num) ZipSparks =
{
   local vector rvec;

   while (num > 0)
   {
      rvec_x = crandom()*targ.maxs_x + targ.origin_x;
      rvec_y = crandom()*targ.maxs_y + targ.origin_y;
      rvec_z = crandom()*targ.maxs_z + targ.origin_z;

      particle(rvec, dir, 232, 70);

      num = num - 1;
   }
};

void() ZipTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;
   if (!other.slide_on) return;
   if (other.ziptime > time) return;

   other.ziptime = time + 0.5;

   local float ospeed;

   ospeed = vlen(other.velocity);
   
   if (self.max_health > 0)
      if (ospeed > self.max_health) return;

   makevectors(self.mangle);

   v_forward_z = 0 - v_forward_z;

   other.velocity = other.velocity + v_forward*self.health;

   ZipSparks(other, v_forward*self.health, 10);

   sound(self, CHAN_AUTO, "zip.wav", 1, ATTN_NORM);
};

void() point_zip =
{
   if ((self.spawnflags & DMONLY) && !deathmatch) {remove(self); return;}

   traceline (self.origin, self.origin - '0 0 256', TRUE, self);

   droptofloor();

   self.mangle = self.angles;

   self.angles = vectoangles(trace_plane_normal);

   self.angles_z = self.mangle_y + 180;

   self.touch = ZipTouch;

   precache_sound("zip.wav");
   precache_model("progs/zipper.mdl");

   setmodel(self, "progs/zipper.mdl");
   setorigin(self, self.origin);

   self.classname = "zipperpoint";

   self.movetype = MOVETYPE_NONE;
   self.solid = SOLID_TRIGGER;

   self.skin = 0;

   setsize (self, VEC_HULL2_MIN, VEC_HULL2_MAX);
};

//Makes drippy bits for start point
void() StartPointThink =
{
   particle(self.origin + '0 0 50', '0 0 -7', 40, 50);

   self.nextthink = time + 0.1 + random()*0.8;
};

//When a player touches a start point or start field
void() StartTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;
   if (other.slide_on) return;

   local entity stemp;
   stemp = self;
   self = other;

   Slide_On();

   self = stemp;

   other.slide_points = 1;

   other.slide_time = time;

   if (self.classname == "startpoint")
   {
      spawn_tfog(self.origin);
      sound (self, CHAN_AUTO, "go.wav", 1, ATTN_NORM);
   }
   else if (self.classname == "startfield")
   {
      spawn_tfog(other.origin);
      sound (other, CHAN_AUTO, "go.wav", 1, ATTN_NORM);
   }

   centerprint(other,"GO!");
};

//Start Point
void() point_start =
{
   droptofloor();

   precache_sound ("go.wav");

   precache_model("progs/spoint.mdl");
   setmodel(self, "progs/spoint.mdl");

   self.classname = "startpoint";

   self.touch = StartTouch;

   self.think = StartPointThink;
   self.nextthink = time;

   self.movetype = MOVETYPE_NONE;
   self.solid = SOLID_TRIGGER;

   setsize (self, '-16 -16 0', '16 16 56');
};

void() GlowOn =
{
   if (!(self.spawnflags & NOGLOW))
      self.effects = self.effects | EF_DIMLIGHT;

   self.skin = 0;
   self.nextthink = time + 1;
   self.think = GlowOff;
};

//Turns the glow off from checkpoints and endpoints.
void() GlowOff =
{
   self.skin = 1;
   self.effects = self.effects - (self.effects & EF_DIMLIGHT);
};

void() EndStuff =
{
   local entity stemp;
   stemp = self;
   self = other;

   if (self.slide_on)
      Spawn_ABoard();

   Slide_Off();

   self = stemp;

   other.slide_points = 0;
   other.frags = other.frags + 5;

   local float temptime;
   local string strtmp;

   temptime = time - other.slide_time;

   if (deathmatch)
   {
      bprint(other.netname);
      bprint(" finished in");
      strtmp = ftos(temptime);
      bprint(strtmp);
      bprint(" seconds.\n");
   }

   if (temptime > 0 && temptime < timebest)
   {
       sprint(other, "Record Time! ");
       if (deathmatch)
          sprint(other, "Two extra frags for you.");
       sprint(other, "\n");

       namebest = other.netname;

       timebest = temptime;
       other.frags = other.frags + 2;
   }
   else
   {
      sprint(other,"Best time:");
      strtmp = ftos(timebest);
      sprint(other, strtmp);

      if (deathmatch)
      {
         sprint(other, " <");
         sprint(other, namebest);
         sprint(other, ">");
      }

      sprint(other,"\n");
   }

   if (!deathmatch)
   {
      sprint(other,"Your time:");
      strtmp = ftos(temptime);
      sprint(other, strtmp);
      sprint(other," secs.\n");
   }

   other.attack_finished = time + 0.7;

   if (self.classname == "endpoint")
      sound (self, CHAN_AUTO, "buzz.wav", 1, ATTN_NORM);
   else
   if (self.classname == "endfield")
      sound (other, CHAN_AUTO, "buzz.wav", 1, ATTN_NORM);

   centerprint(other,"Finished!");
};

//When a player checks an endpoint.
void() EndPointTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;
   if (!other.slide_points) return;

   if (other.slide_points != checkcfg)
   {
      centerprint(other, "Hit the checkpoints first.");

      if (!(sflags & SF_NOCHECKGIB))
      {
         T_Damage(other, self, self, 10000);
         return;
      }

      if (other.slide_on) other.velocity = '0 0 0' - other.velocity;
      return;
   }

   EndStuff();

   self.think = GlowOn;
   self.nextthink = time;
};

//End Point
void() point_end =
{
   traceline (self.origin, self.origin - '0 0 256', TRUE, self);

   droptofloor();

   self.angles = vectoangles(trace_plane_normal);
   self.angles_z = crandom()*180;

   self.touch = EndPointTouch;

   precache_sound ("buzz.wav");
   precache_model("progs/epoint.mdl");

   setmodel(self, "progs/epoint.mdl");
   setorigin(self, self.origin);

   self.classname = "endpoint";

   self.movetype = MOVETYPE_NONE;
   self.solid = SOLID_TRIGGER;

   self.skin = 1;

   setsize (self, VEC_HULL2_MIN, VEC_HULL2_MAX);
};

//When players touch a checkpoint
void() CheckPointTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;
   if (!(other.slide_points & 1)) return;
   if (other.slide_points & self.slide_points) return;

   other.slide_points = other.slide_points | self.slide_points;

   self.think = GlowOn;
   self.nextthink = time;

   sound (self, CHAN_AUTO, "ding.wav", 1, ATTN_NORM); 

   sprint(other, "Checkpoint!\n");
};

//Check Point
void() point_check =
{
   traceline (self.origin, self.origin - '0 0 256', TRUE, self);

   droptofloor();

   self.angles = vectoangles(trace_plane_normal);
   self.angles_z = crandom()*180;

   precache_sound ("ding.wav");
   precache_model("progs/cpoint.mdl");

   setmodel(self, "progs/cpoint.mdl");

   self.touch = CheckPointTouch;

   self.movetype = MOVETYPE_NONE;
   self.solid = SOLID_TRIGGER;

   self.classname = "checkpoint";

   self.skin = 1;

   setsize (self, VEC_HULL2_MIN, VEC_HULL2_MAX);
};

//When you touch a reslide point or reslide field
void() ReslideTouch =
{
   if (other.classname != "player") return;
   if (other.slide_on) return;
   if (!other.slide_points) return;
   if (other.health < 1) return;

   local entity stemp;
   stemp = self;
   self = other;

   Slide_On();

   self = stemp;

   if (self.classname == "reslidepoint")
      spawn_tfog(self.origin);
   else if (self.classname == "reslidefield")
      spawn_tfog(other.origin);
};

//Reslide Point
void() item_reslide =
{
   traceline (self.origin, self.origin - '0 0 256', TRUE, self);

   droptofloor();

   self.angles = vectoangles(trace_plane_normal);
   self.angles_z = crandom()*180;

   precache_model("progs/reslide.mdl");
   setmodel(self, "progs/reslide.mdl");

   self.touch = ReslideTouch;

   self.movetype = MOVETYPE_NONE;
   self.solid = SOLID_TRIGGER;

   self.classname = "reslidepoint";

   setsize (self, '-20 -20 0', '20 20 56');
};

//When you touch a bonus item
void() BonusTouch =
{
   if (other.classname != "player") return;
   if (!other.slide_on) return;

   other.frags = other.frags + 1;

   self.solid = SOLID_NOT;
   self.model = string_null;
   self.nextthink = time + 20;
   self.think = SUB_regen;

   sprint(other, "Bonus point!\n");

   self.avelocity_x = crandom()*360;
   self.avelocity_y = crandom()*360;
   self.avelocity_z = crandom()*360;

   sound(other, CHAN_ITEM, "whoosh.wav", 1, ATTN_NORM);
   stuffcmd (other, "bf\n");
	
   activator = other;
   SUB_UseTargets();

   other.effects = other.effects | EF_MUZZLEFLASH;
};

//Bonus item. Gives players a frag.
void() item_bonus =
{
   self.touch = BonusTouch;

   precache_sound ("whoosh.wav");

   precache_model ("progs/bonus2.mdl");
   setmodel (self, "progs/bonus2.mdl");

   setsize (self, '-16 -16 -24', '16 16 24');

   self.classname = "bonus";

   self.mdl = self.model;
   self.flags = FL_ITEM;
   self.solid = SOLID_TRIGGER;
   self.movetype = MOVETYPE_FLY;

   self.avelocity_x = crandom()*360;
   self.avelocity_y = crandom()*360;
   self.avelocity_z = crandom()*360;
};

//**************************************************************************
//TRIGGERS (fields)
//**************************************************************************

//Makes drippy bits for start point
void() ZipFieldThink =
{
   local float rand1, rand2, rand3;
   local vector randv;

   rand1 = self.mins_x + random()*self.size_x;
   rand2 = self.mins_y + random()*self.size_y;
   rand3 = self.mins_z + random()*self.size_z;

   randv = '1 0 0'*rand1 + '0 1 0'*rand2 + '0 0 1'*rand3;

   particle(randv, self.v_angle * 10, 232, 50);

   self.nextthink = time + 0.1;
};

void() ZipFieldTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;
   if (!other.slide_on) return;
   if (other.ziptime > time) return;

   other.ziptime = time + 0.1;

   local float ospeed;

   ospeed = vlen(other.velocity);
   
   if (self.max_health > 0)
      if (ospeed > self.max_health) return;

   makevectors(self.mangle);

   v_forward_z = 0 - v_forward_z;

   other.velocity = other.velocity + v_forward*self.health;

   ZipSparks(other, v_forward*self.health, 1);

//   sound(other, CHAN_AUTO, "zip.wav", 1, ATTN_NORM);
};

//zip brush
void() trigger_zip =
{
   if ((self.spawnflags & DMONLY) && !deathmatch) {remove(self); return;}

   self.mangle = self.angles;

   makevectors(self.mangle);
   v_forward_z = 0 - v_forward_z;

   self.v_angle = v_forward;

   InitTrigger();

   precache_sound("zip.wav");

   self.classname = "zipfield";

   self.touch = ZipFieldTouch;

   self.think = ZipFieldThink;
   self.nextthink = time;
};

//touch for the impact thingy
void() ImpactFieldTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;

   local float ospeed, dam;

   ospeed = vlen(other.velocity);

   if (ospeed < 400) return;

   dam = ospeed * 0.08;

   T_Damage(other, self, self, dam);

   other.velocity = '0 0 0';
};

//field that does dsamage based on player velocity. for spikes and stuff.
void() trigger_impact =
{
   InitTrigger();

   self.classname = "impactfield";

   self.touch = ImpactFieldTouch;
};

//Sets players' attack finished ahead so they can't shoot.
void() PeaceFieldTouch =
{
   if (other.classname != "player") return;
   if (self.attack_finished > time) return;
   if (other.health < 1) return;

   self.attack_finished = time + 1;
   other.attack_finished = time + 1.1;
};

//Players can't shoot. For observation booths and MAYBE start areas.
void() trigger_peace =
{
   InitTrigger();

   self.classname = "peacefield";

   self.touch = PeaceFieldTouch;
};

//Makes drippy bits for start field. NOT currently used
void() StartFieldThink =
{
   local float rand1, rand2, rand3;
   local vector randv;

   rand1 = self.mins_x + random()*self.size_x;
   rand2 = self.mins_y + random()*self.size_y;
   rand3 = self.mins_z + random()*self.size_z;

   randv = '1 0 0'*rand1 + '0 1 0'*rand2 + '0 0 1'*rand3;

   particle(self.origin + randv, '0 0 0', 40, 50);

   self.nextthink = time + 0.1;
};

//Flashy start field
void() StartFlash =
{
   if (self.health)
   {
      setmodel (self, self.netname);
      self.modelindex = self.lefty;

      self.health = 0;

      self.nextthink = time + 0.05;
   }
   else
   {
      self.modelindex = 0;

      self.health = 1;

      self.nextthink = time + 0.1;
   }
};

//Start Field
void() trigger_start =
{
   precache_sound ("go.wav");

   self.netname = self.model;
   self.classname = "startfield";

   self.touch = StartTouch;

   self.think = StartFlash;
   self.nextthink = time;

   setmodel(self, self.model);

   self.lefty = self.modelindex;

   InitTrigger();
};

//When players touch a Endpoint FIELD
void() EndFieldTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;
   if (!other.slide_points) return;

   if (other.slide_points != checkcfg)
   {
      centerprint(other, "Hit the checkpoints first.");

      if (!(sflags & SF_NOCHECKGIB))
      {
         T_Damage(other, self, self, 10000);
         return;
      }

      if (other.slide_on) other.velocity = '0 0 0' - other.velocity;
      return;
   }

   EndStuff();

   local entity dummy;

//   dummy = find (world, targetname, self.targetname);
   dummy = find (world, targetname, self.target);

   if (dummy == world) objerror("You need at least one dummy with the same targetname as this checkpoint trigger's target!");
   while (dummy != world)
   {
      if (dummy.classname == "enddummy")
      {
         dummy.think = GlowOn;
         dummy.nextthink = time;
      }

//      dummy = find (dummy, targetname, self.targetname);
      dummy = find (dummy, targetname, self.target);
   }
};


//Endpoint field
void() trigger_end =
{
   InitTrigger();

   precache_sound ("buzz.wav");

   self.classname = "endfield";

   self.touch = EndFieldTouch;
};

//Dummy endpoint poles for endpoint fields
void() dummy_end =
{
   traceline (self.origin, self.origin - '0 0 256', TRUE, self);

   droptofloor();

   self.angles = vectoangles(trace_plane_normal);
   self.angles_z = crandom()*180;

   precache_model("progs/epoint.mdl");
   setmodel(self, "progs/epoint.mdl");

   self.movetype = MOVETYPE_NONE;
   self.solid = SOLID_NOT;

   self.classname = "enddummy";

   self.skin = 1;
};

//When players touch a Checkpoint FIELD
void() CheckFieldTouch =
{
   if (other.classname != "player") return;
   if (other.health < 1) return;
   if (!(other.slide_points & 1)) return;
   if (other.slide_points & self.slide_points) return;

   other.slide_points = other.slide_points | self.slide_points;

   local entity dummy;

//   dummy = find (world, targetname, self.targetname);
   dummy = find (world, targetname, self.target);

   if (dummy == world) objerror("You need at least one dummy with the same targetname as this checkpoint trigger!");
   while (dummy != world)
   {
      if (dummy.classname == "checkdummy")
      {
         dummy.think = GlowOn;
         dummy.nextthink = time;
      }

//      dummy = find (dummy, targetname, self.targetname);
      dummy = find (dummy, targetname, self.target);
   }

   sound (other, CHAN_AUTO, "ding.wav", 1, ATTN_NORM); 

   sprint(other, "Checkpoint!\n");
};

//Checkpoint field
void() trigger_check =
{
   InitTrigger();

   precache_sound ("ding.wav");

   self.classname = "checkfield";

   self.touch = CheckFieldTouch;
};

//Dummy checkpoint poles for checkpoint fields
void() dummy_check =
{
   traceline (self.origin, self.origin - '0 0 256', TRUE, self);

   droptofloor();

   self.angles = vectoangles(trace_plane_normal);
   self.angles_z = crandom()*180;

   precache_model("progs/cpoint.mdl");
   setmodel(self, "progs/cpoint.mdl");

   self.movetype = MOVETYPE_NONE;
   self.solid = SOLID_NOT;

   self.classname = "checkdummy";

   self.skin = 1;
};

//Flashy reslide field
void() ReslideFlash =
{
   if (self.health)
   {
      setmodel (self, self.netname);
      self.modelindex = self.lefty;

      self.health = 0;

      self.nextthink = time + 0.05;
   }
   else
   {
      self.modelindex = 0;

      self.health = 1;

      self.nextthink = time + 0.5 + random();
   }
};

//Reslide Field
void() trigger_reslide =
{
   self.netname = self.model;
   self.classname = "reslidefield";

   self.touch = ReslideTouch;

   self.think = ReslideFlash;
   self.nextthink = time;

   setmodel(self, self.model);

   self.lefty = self.modelindex;

   InitTrigger();
};

//touching the trip thingy
void() TripTouch =
{
   if (other.classname != "player") return;
   if (!other.slide_on) return;

   local entity stemp;

   stemp = self;
   self = other;

   Slide_Off();

   Spawn_Board();

   player_trip1();

   self = stemp;
};

//Makes players trip
void() trigger_trip =
{
   InitTrigger();

   self.classname = "tripfield";

   self.touch = TripTouch;
};

//**************************************************************************
//MISC
//**************************************************************************


void() NextSlideLev =
{
   if (cvar("noexit") == 4)
   {
      if (world.model == "maps/slide1.bsp" ||
          world.model == "maps/slide2.bsp" ||
          world.model == "maps/slide3.bsp" ||
          world.model == "maps/slide4.bsp" ||
          world.model == "maps/slide5.bsp" ||
          world.model == "maps/slide6.bsp" ||
          world.model == "maps/slide7.bsp" ||
          world.model == "maps/slide8.bsp" ||
          world.model == "maps/slide9.bsp" ||
          world.model == "maps/halfpipe.bsp")
          nextmap = "slstart";

          return;
   }

   if (cvar("noexit") == 3)
   {
      local float rand;
      rand = ceil(random()*10);

      if (rand == 1) nextmap = "slide1";
      if (rand == 2) nextmap = "slide2";
      if (rand == 3) nextmap = "slide3";
      if (rand == 4) nextmap = "slide4";
      if (rand == 5) nextmap = "slide5";
      if (rand == 6) nextmap = "slide6";
      if (rand == 7) nextmap = "slide7";
      if (rand == 8) nextmap = "slide8";
      if (rand == 9) nextmap = "slide9";
      if (rand == 10) nextmap = "slstart";

      return;
   }

   if (world.model == "maps/slstart.bsp")
      nextmap = "slide1";
   if (world.model == "maps/slide1.bsp")
      nextmap = "slide2"; else
   if (world.model == "maps/slide2.bsp")
      nextmap = "slide3"; else
   if (world.model == "maps/slide3.bsp")
      nextmap = "slide4"; else   
   if (world.model == "maps/slide4.bsp")
      nextmap = "slide5"; else   
   if (world.model == "maps/slide5.bsp")
      nextmap = "slide6"; else   
   if (world.model == "maps/slide6.bsp")
      nextmap = "slide7"; else   
   if (world.model == "maps/slide7.bsp")
      nextmap = "slide8"; else   
   if (world.model == "maps/slide8.bsp")
      nextmap = "slide9"; else   
   if (world.model == "maps/slide9.bsp")
      nextmap = "slstart";
   if (world.model == "maps/halfpipe.bsp")
      nextmap = "slstart";
};

void() MOTD =
{
   if (self.motd_count < 4)
   {
      self.motd_time = time + 1;
      self.motd_count = self.motd_count + 1;
      if (deathmatch || coop)
         centerprint(self,"SLIDE v1.1\nžƒžžžžžžžžžžžžžžžžžžžžžžžžƒžŸ\nRun through the blue field...\n...grab yer board...\n...race to the bottom!\nžžžžžžžžžžžžžžžžžžžžŸ\nWritten by ŽÓéÎÇÅ\nžƒžžžžžžžžžžžžžžžžžžžžžžžžƒžŸ\nE-mail: singe@ix.netcom.com\nVisit the Slide site at:\nsinge.telefragged.com/slide/slide.html");
   }
};

//Find all checkpoints in the level and assign them a bitflag.
void() Set_Check =
{
   local float bitflag;
   local entity e;

   bitflag = 1;

   e = find (world, classname, "checkpoint");
   while (e != world)
   {
      bitflag = bitflag * 2;
      e.slide_points = bitflag;
      checkcfg = checkcfg | bitflag;
      e = find (e, classname, "checkpoint");
   }

   e = find (world, classname, "checkfield");
   while (e != world)
   {
      bitflag = bitflag * 2;
      e.slide_points = bitflag;
      checkcfg = checkcfg | bitflag;
      e = find (e, classname, "checkfield");
   }
};

//Is this used?
void() Board_Think =
{
   if (self.attack_finished < time)
   {
      self.think = SUB_Remove;
      self.nextthink = time + 20;
      return;
   }

   self.nextthink = time;
   self.flags = self.flags-(self.flags&FL_ONGROUND);
};

//Spawning a board for when you die, or hit lava, or trip.
void() Spawn_Board =
{
   local entity board;

   board = spawn();

   board.movetype = MOVETYPE_BOUNCE;
   board.solid = SOLID_NOT;
   board.owner = self;

   setorigin(board, self.origin);

   setmodel(board, "progs/board.mdl");
   setsize(board, '-32 -32 -10', '32 32 10');

   board.angles = self.angles;
   board.avelocity_x = random()*360 - 180;
   board.avelocity_y = random()*360 - 180;
   board.avelocity_z = random()*360 - 180;

   board.flags = board.flags-(board.flags&FL_ONGROUND);

   board.velocity = self.velocity + '0 0 300';

   board.think = SUB_Remove;
   board.nextthink = time + 20;
};

//The animation
void() aniboard  = [0, aniboard1] {};
void() aniboard1 = [1, aniboard2] {};
void() aniboard2 = [2, aniboard3] {};
void() aniboard3 = [3, aniboard4] {};
void() aniboard4 = [4, aniboard5] {};
void() aniboard5 = [5, aniboard6] {};
void() aniboard6 = [6, aniboard7] {};
void() aniboard7 = [7, aniboard8] {};
void() aniboard8 = [8, aniboard9] {};
void() aniboard9 = [9,SUB_Remove] {particle(self.origin, '0 0 0', 0, 100);};

//Spawning a board for when you deactivate it or reach the end.
void() Spawn_ABoard =
{
   local entity board;

   board = spawn();

   board.movetype = MOVETYPE_FLY;
   board.solid = SOLID_NOT;
   board.owner = self;

   setorigin(board, self.origin);

   setmodel(board, "progs/board.mdl");
   setsize(board, '0 0 0', '0 0 0');

   board.angles = self.angles;

   if (random() > 0.5) board.avelocity_y = -360; else board.avelocity_y = 360;

   board.flags = board.flags-(board.flags&FL_ONGROUND);

   board.think = aniboard;
   board.nextthink = time;
};
