

DROP SCHEMA IF EXISTS private cascade;
CREATE SCHEMA private;

DROP SCHEMA public CASCADE;
CREATE schema public;


DROP ROLE IF EXISTS perm_admin;
create role perm_admin login password 'xyz';

DROP ROLE IF EXISTS perm_readonly;
create role perm_readonly;
grant perm_readonly to perm_admin;

DROP ROLE IF EXISTS perm_anon_customer;
create role perm_anon_customer;
grant perm_anon_customer to perm_admin;

DROP ROLE IF EXISTS perm_readwrite;
create role perm_readwrite;
grant perm_readwrite to perm_admin;


create or replace function public.fn_current_user_id() returns int as $$
  select coalesce (nullif(current_setting('jwt.claims.user_id', true), '')::int,1); --to do in PROD change this to error if the current setting is NULL
$$ language sql stable set search_path from current;

comment on function  public.fn_current_user_id() is
  E'@omit\nHandy method to get the current user ID for use in Row-Level-Security (RLS) policies, etc; in GraphQL, use `currentUser{id}` instead.';
 
 
 
create or replace function public.fn_set_modified_fields() returns trigger as $$
begin
  new."DateModified" := current_timestamp;
  new."ModifiedBy" := fn_current_user_id();
  return new;
end;
$$ language plpgsql;


-- public."Users" definition

-- Drop table

-- DROP TABLE public."Users";

CREATE TABLE public."Users" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL DEFAULT 1,
	"Permission" int,
	"FirstName" text NULL,
	"LastName" text NULL,
	"OpenIdUrl" text NULL,
	"UserStatus" text NULL,
	"IsClientAdmin" bool NULL,
	"IsApproved" bool NULL,
	"Active" bool NOT NULL DEFAULT True,
	"UserId" int not null default 1,
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT User_pkey PRIMARY KEY ("Id")
);

comment on table  public."Users" is 'Public information about a user’s account.';
comment on column public."Users"."Id" is 'The id of the user also associated with users private account.';
comment on column public."Users"."LocaleId" is 'The users Locale.';
comment on column public."Users"."Permission" is 'The users permission: Anonymous, R/O, R/W or Admin.';
comment on column public."Users"."FirstName" is 'The users last name.';	
comment on column public."Users"."LastName" is 'The users last name.';
comment on column public."Users"."OpenIdUrl" is 'The Open Id URL for authorization and authentication.';
comment on column public."Users"."UserStatus" is 'The users status for joining the system.';
comment on column public."Users"."IsClientAdmin" is 'The user can approve new users.';
comment on column public."Users"."IsApproved" is 'The records last modified date.';
comment on column public."Users"."Active" is 'The user is active (not deactivated).';
comment on column public."Users"."UserId" is 'The user who first created the record.';
comment on column public."Users"."ModifiedBy" is 'The records last modified user.';
comment on column public."Users"."DateCreated" is 'The records created date.';
comment on column public."Users"."DateModified" is 'The records last modified date.';


create trigger tr_User_updated before update
  on public."Users"
  for each row
  execute procedure public.fn_set_modified_fields();
 


-- public."Locales" definition --- ANNOYINGLY "Locale" CONFLICTS WITH A CORE CLASEE IN HOTCHOCOLATE


-- DROP TABLE public."Locales"; --- ANNOYINGLY "Locale" CONFLICTS WITH A CORE CLASEE IN HOTCHOCOLATE

CREATE TABLE public."Locales" (
	"Id" serial4 NOT NULL,
	"Address" text NULL,
	"Suburb" text NULL,
	"PostCode" text NULL,
	"State" text NULL,
	"TaxRate" int4 NOT NULL default 10,
	"Active" bool NULL DEFAULT true,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT Locale_pkey PRIMARY KEY ("Id")
);


create trigger tr_Locale_updated before update
  on public."Locales"
  for each row
  execute procedure public.fn_set_modified_fields();


CREATE EXTENSION if not exists CITEXT;


CREATE TABLE private."UserAccounts" (
	"Id" serial4 primary key references public."Users"("Id") on delete cascade,
	"Email" citext not null unique check (length("Email") <= 255 and ("Email" ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')),
	"PasswordHash" text NOT NULL
);
comment on table  private."UserAccounts" is 'Private information about a user’s account.';
comment on column private."UserAccounts"."Id" is 'The id of the user associated with this account.';
comment on column private."UserAccounts"."Email" is 'The email address of the user.';
comment on column private."UserAccounts"."PasswordHash" is 'An opaque hash of the user’s password.';


 
ALTER SEQUENCE public."Users_Id_seq" RESTART 1;

INSERT INTO public."Users" ("LocaleId","Permission","FirstName","LastName","OpenIdUrl","UserStatus","Active","IsClientAdmin","IsApproved","UserId") VALUES
(1,5,'Admin','Admin','http://openid.net','Registered',true,true,true,1);

ALTER SEQUENCE private."UserAccounts_Id_seq" RESTART 1;
INSERT INTO private."UserAccounts" ("Id","Email","PasswordHash") VALUES
(1,'info@JeremyThompson.Net','dfgfd346');  ---This is hashed passedword, you'll see the function to register users below

	
ALTER SEQUENCE public."Locales_Id_seq" RESTART 1;
INSERT INTO public."Locales" ("Address","Suburb","PostCode","State", "TaxRate", "UserId") VALUES ('51 Parade Ave','Mooe Park','2021','NSW', 10, 1);
INSERT INTO public."Locales" ("Address","Suburb","PostCode","State", "TaxRate", "UserId") VALUES ('Meblourne Criket Groud','Albert Park','3021','VIC', 10, 1);
INSERT INTO public."Locales" ("Address","Suburb","PostCode","State", "TaxRate", "UserId") VALUES ('Subiaco Oval','Subiaco','6008','WA', 10, 1);

alter table public."Users" add CONSTRAINT FK_User_Locale FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id");


 


--------------------------------
--TABLES
--------------------------------



-- public."Settings" definition

-- Drop table

-- DROP TABLE public."Settings";

CREATE TABLE public."Settings" (
	"Id" serial NOT NULL,
	"SettingProperty" text NOT NULL,
	"Description" text NOT NULL,
	CONSTRAINT Settings_pkey PRIMARY KEY ("Id")
);

comment on table  public."Settings" is 'Global application settings that affect all Locales.';
comment on column public."Settings"."Id" is 'The setting id.';
comment on column public."Settings"."SettingProperty" is 'The setting value.';
comment on column public."Settings"."Description" is 'The setting description.';




-- Support for LIKE's Stored Procedures/Functions
CREATE EXTENSION pg_trgm;
CREATE EXTENSION btree_gin;

-- public."Banners" definition

-- Drop table

-- DROP TABLE public."Banners";

CREATE TABLE public."Banners" (
	"Id" serial4 NOT NULL,
	"Url" text NULL,
	"IsDeleted" bool NOT NULL,
	CONSTRAINT Banners_pkey PRIMARY KEY ("Id")
);




-- public."Employees" definition

-- Drop table

-- DROP TABLE public."Employees";

CREATE TABLE public."Employees" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL DEFAULT 1,	"TitleSettingId" int4 NOT NULL DEFAULT 8,
	"FirstName" text NULL,
	"LastName" text NULL,
	"Phone" text NULL,
	"Mobile" text NULL,
	"Email" text NULL,
	"Address1" text NULL,
	"Address2" text NULL,
	"Suburb" text NULL,
	"State" text NULL,
	"PostCode" text NULL,	
	"CountrySettingId" int NOT NULL default 1712,
	"Sex" text NULL,
	"DateOfBirth" Date NULL,
	"Active" bool NOT NULL DEFAULT true,
	"Leave" timestamptz NULL,
	"ReturnFromLeave" timestamptz NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT Resource_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_Resource_Locale FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id"),
	CONSTRAINT FK_Title_Settings FOREIGN KEY ("TitleSettingId") REFERENCES public."Settings"("Id"),
	CONSTRAINT FK_Country_Settings FOREIGN KEY ("CountrySettingId") REFERENCES public."Settings"("Id")
);


CREATE INDEX EmployeeFirstNameTxtSearch_idx ON public."Employees" USING gin("FirstName");
CREATE INDEX EmployeeLastNameTxtSearch_idx ON public."Employees" USING gin("LastName");

create trigger tr_Resource_updated before update
  on public."Employees"
  for each row
  execute procedure public.fn_set_modified_fields();
 
 


-- public."Attendees" definition

-- Drop table

-- DROP TABLE public."Attendees";

CREATE TABLE public."Attendees" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL DEFAULT 1,
	"MembershipId" text NULL,
	"TitleSettingId" int4 NOT NULL DEFAULT 9,
	"FirstName" text NULL check(length("FirstName") <= 40),
	"LastName" text NULL check(length("LastName") <= 60),
	"Occupation" text NULL,
	"IndustrySettingId" int4 NULL,
	"Phone" text NULL,
	"Mobile" text NULL,
	"Email" citext NULL check(length("Email") <= 255 and ("Email" ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')),
	"Sex" text NOT NULL DEFAULT '',
	"VOIPPhone" text NULL,
	"Address1" text NULL,
	"Address2" text NULL,
	"Suburb" text NULL,
	"State" text NULL,
	"PostCode" text NULL,
	"CountrySettingId" int4 NULL,
	"DateOfBirth" Date NULL,
	"Active" bool NOT NULL DEFAULT true,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT attendee_pkey PRIMARY KEY ("Id"),	
	CONSTRAINT FK_attendee_Locale FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id"),
	CONSTRAINT FK_attendeeTitle_Settings FOREIGN KEY ("TitleSettingId") REFERENCES public."Settings"("Id"),
	CONSTRAINT FK_attendeeCountry_Settings FOREIGN KEY ("CountrySettingId") REFERENCES public."Settings"("Id"),
	CONSTRAINT FK_attendeeInd_Settings FOREIGN KEY ("IndustrySettingId") REFERENCES public."Settings"("Id")
);

CREATE INDEX attendee_title_idx ON public."Attendees" USING btree ("TitleSettingId");
CREATE INDEX attendee_postcode_idx ON public."Attendees" USING btree ("PostCode");

CREATE INDEX AttendeeFirstNameTxtSearch_idx ON public."Attendees" USING gin("FirstName");
CREATE INDEX AttendeeLastNameTxtSearch_idx ON public."Attendees" USING gin("LastName");


create trigger tr_attendee_updated before update
  on public."Attendees"
  for each row
  execute procedure public.fn_set_modified_fields();
 



-- public."Events" definition

-- Drop table

-- DROP TABLE public."Events";

CREATE TABLE public."Events" (
	"Id" serial4 NOT NULL,
	"EmployeeId" int4 NOT NULL DEFAULT 1,
	"LocaleId" int4 NOT NULL DEFAULT 1,
	"BannerId" int4 NULL,
	"Description" text NULL,
	"Address" text NOT NULL,
	"StartTime" timestamptz NULL,
	"EndTime" timestamptz NULL,
	"Price" decimal(19,2) NOT NULL DEFAULT 0,
	"MaxCapacity" int4 NOT NULL DEFAULT 10,
	"SendReminder" bool NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT Events_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_Events_Employee FOREIGN KEY ("EmployeeId") REFERENCES public."Employees"("Id"),	
	CONSTRAINT FK_Events_Banner FOREIGN KEY ("BannerId") REFERENCES public."Banners"("Id"),	
	CONSTRAINT FK_Events_Locale FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id")
);
CREATE INDEX Events_LocaleStartEnd_idx ON public."Events" ("LocaleId","StartTime","EndTime");


create trigger tr_Events_updated before update
  on public."Events"
  for each row
  execute procedure public.fn_set_modified_fields();

 

 
-- public."EventAttendees" definition

-- Drop table

-- DROP TABLE public."EventAttendees";

CREATE TABLE public."EventAttendees" (
	"Id" serial4 NOT NULL,
	"EventId" int4 NOT NULL,
	"AttendeeId" int4 NOT NULL,
	"InAttendence" bool NOT NULL DEFAULT FALSE,
	"Cancelled" bool NOT NULL DEFAULT FALSE,
	"SurveyRating" int4 NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT EventAttendees_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_EventAttendees_Events FOREIGN KEY ("EventId") REFERENCES public."Events"("Id") on delete cascade,
	CONSTRAINT FK_EventAttendees_Attendee FOREIGN KEY ("AttendeeId") REFERENCES public."Attendees"("Id")
);
CREATE INDEX EventAttendees_Attendeeid_idx ON public."EventAttendees" USING btree ("AttendeeId");
CREATE INDEX EventAttendees_Eventid_idx ON public."EventAttendees" USING btree ("EventId");


 
 

create extension if not exists "pgcrypto";


alter default privileges revoke execute on functions from public;

create or replace function public.fn_Register_User(
  "LocaleId" int4,
  "Permission" int,
  "FirstName" text,
  "LastName" text,
  "Email" text,  
  "Password" text,
  "IsClientAdmin" bool,
  "IsApproved" bool,
  "OpenIdUrl" text,
  "UserId" int4
) returns public."Users" as $$
declare
  User public."Users";
begin
  insert into public."Users" ("LocaleId","Permission", "FirstName", "LastName", "OpenIdUrl", "IsClientAdmin", "IsApproved", "UserId") values
    (LocaleId, Permission, FirstName, LastName, OpenIdUrl, IsClientAdmin, IsApproved, UserId)
    returning * into User;

  insert into private.Useraccount ("Id", "Email", "PasswordHash") values
    (public."Users".Id, email, crypt(Password, gen_salt('bf')));

  return User;
end;
$$ language plpgsql strict security definer;

comment on function public.fn_Register_User(int4, int, text, text, text, text, bool, bool, text,int4) is 'Registers a single user and creates an account in the private schema.';






grant usage on schema private to perm_admin;

--MAKE THE private.Useraccount have RLS so only users can change their own records
alter table private."UserAccounts" enable row level security;

create policy update_user_account on private."UserAccounts" for update to perm_readwrite
  using ("Id" = current_setting('jwt.claims.id', true)::integer);

grant select on table private."UserAccounts" to perm_readonly, perm_readwrite, perm_admin;
grant update, delete on table private."UserAccounts" to perm_readonly, perm_readwrite, perm_admin; 

grant usage on schema public to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;

grant select on table public."Users" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Users" to perm_readonly, perm_readwrite, perm_admin;
grant usage on sequence public."Users_Id_seq" to perm_readonly, perm_readwrite, perm_admin;

grant select on table public."Events" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert on table public."Events" to perm_anon_customer, perm_readwrite, perm_admin;
grant update, delete on table public."Events" to perm_readwrite, perm_admin;
grant usage on sequence public."Events_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

grant select on table public."EventAttendees" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert on table public."EventAttendees" to perm_anon_customer, perm_readwrite, perm_admin;
grant update, delete on table public."EventAttendees" to perm_readwrite, perm_admin;
grant usage on sequence public."EventAttendees_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

grant select on table public."Attendees" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert on table public."Attendees" to perm_anon_customer, perm_readwrite, perm_admin;
grant update, delete on table public."Attendees" to perm_readwrite, perm_admin;
grant usage on sequence public."Attendees_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

grant select on table public."Employees" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Employees" to perm_readwrite, perm_admin;
grant usage on sequence public."Employees_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."Banners" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Banners" to perm_readwrite, perm_admin;
grant usage on sequence public."Banners_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."Locales" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Locales" to perm_admin;
grant usage on sequence public."Locales_Id_seq" to perm_admin;

grant select on table public."Settings" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Settings" to perm_admin;
grant usage on sequence public."Settings_Id_seq" to perm_admin;




grant execute on function public.fn_current_user_id() to perm_readwrite, perm_admin;
grant execute on function public.fn_set_modified_fields() to perm_readwrite, perm_admin;

grant execute on function public.fn_Register_User(int4, int, text, text, text, text, bool, bool, text,int4) to  perm_readwrite, perm_admin;




ALTER SEQUENCE public."Settings_Id_seq" RESTART 1;


INSERT INTO public."Settings" ("SettingProperty","Description") VALUES
	 ('No working on Sunday''s','Weekly Note'),
	 ('Monday Team Meeting','Weekly Note'),
	 ('Tuesday Weekly Accounts','AWeekly Note'),
	 ('Potluck Lunch Wednesdays','Weekly Note'),
	 ('Retrospective/Ceremony','Weekly Note'),
	 ('Clean Premises','Weekly Note'),
	 ('Review Roster','Weekly Note'),
	 ('','Title'),
	 ('Ms','Title'),
	 ('Mr','Title'),
	 ('Mrs','Title'),
	 ('Dr','Title'),
	 ('Prof','Title'),
	 ('Dame','Title'),
	 ('Sir','Title'),
	 ('Lady','Title'),
	 ('Lord','Title');
	
	

ALTER SEQUENCE public."Settings_Id_seq" RESTART 200;

INSERT INTO public."Settings" ("SettingProperty","Description") VALUES
	 ('0','Log out after 30mins'),
	 ('0','Default Payment Option (Cash, Cheque OR Credit)'),
	 ('1','Website Skin/Color'),
	 ('1','Default Send Reminders'),
	 ('1','Tooltips'),
	 ('1','Searches Default By Locale'),
	 ('1','Users Require Admin Permission'),
	 ('0','Reports Require Admin Permission'),
	 ('1','Editing Event Attendees Requires Admin Permission (Day after attendee paid)'),
	 ('1','Marketing To All (NOT By Locale) Requires Admin Permission'),
	 ('0','No Helpful MessagePrompts'),
	 ('0','Hide Invoice Label'),
	 ('1199','Default Industry Id'),
	 ('VIC','Default Suburb/PostCode to Locale'),
	 ('1712','Default attendee Country Id'), -- Australia
	 ('8','Default attendee Title Id'), -- ''
	 ('0','Default attendee Gender'), -- '','Other','Female','Male'
	 ('01/01/2000','Default DateOfBirth'),
	 ('1500','Default Attendee Industry'), -- Professionals
	 ('1','Mandatory Attendee FirstName'),
	 ('1','Mandatory Attendee LastName'),
	 ('1','Mandatory Attendee Mobile'),	 
	 ('1','Mandatory Attendee Email');

ALTER SEQUENCE public."Settings_Id_seq" RESTART 1199;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES 	 ('','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1200;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES 	 ('Accommodation and Food Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1220;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES ('Administrative and Support Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1240;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Agriculture, Forestry and Fishing','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1260;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Arts and Recreation Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1280;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Construction','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1300;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Education and Training','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1320;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Entertainment Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1340;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Executive','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1360;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Financial and Insurance Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1370;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Government and Defence','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1380;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Health Care and Social Assistance','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1390;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Hospitality, Travel and Tourism','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1400;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('IT and Telco','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1420;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES ('Manufacturing','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1440;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Media, Advertising and Arts','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1460;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Mining, Oil and Gas','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1480;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Personal Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1500;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Professional, Scientific and Tech. Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1520;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Public Administration and Safety','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1540;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Real Estate Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1560;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Retail Trade','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1570;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Retired','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1580;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Student/Graduate','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1590;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Trades and Services Reports','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1600;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES ('Transport, Postal and Warehousing','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1620;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Utility Elec., Gas, Water, Waste Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1640;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Wholesale Trade','Industry');


ALTER SEQUENCE public."Settings_Id_seq" RESTART 1700;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Aaland' ,N'358');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Abkhazia' ,N'7');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Afghanistan' ,N'93');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Albania' ,N'355');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Algeria' ,N'2137');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'American Samoa' ,N'684');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Andorra' ,N'376');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Anguilla' ,N'1264');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Anla' ,N'244');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Antarctica' ,N'672');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Antigua' ,N'1268');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Argentina' ,N'54');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Armenia' ,N'3748');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Aruba' ,N'297');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ascension' ,N'247');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Australia' ,N'61');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Australia Northern Territory' ,N'672');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Austria' ,N'43');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Azerbaijan' ,N'9948');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bahamas' ,N'1242');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bahrain' ,N'973');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bangladesh' ,N'880');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Barbados' ,N'1246');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Barbuda' ,N'1268');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Belarus' ,N'3758');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Belgium' ,N'32');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Belize' ,N'501');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Benin' ,N'229');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bermuda' ,N'1441');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bhutan' ,N'975');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bolivia' ,N'591');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bosnia & Herzevina' ,N'387');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Botswana' ,N'267');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Brazil' ,N'55');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'British Virgin Islands' ,N'1284');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Brunei Darussalam' ,N'673');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bulgaria' ,N'359');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Burkina Faso' ,N'226');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Burundi' ,N'257');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'CÃ´ted''Ivoire' ,N'225');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cambodia' ,N'855');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cameroon' ,N'237');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Canada' ,N'11');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'CapeVerde Islands' ,N'238');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cayman Islands' ,N'1345');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Central African Republic' ,N'236');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Chad' ,N'23515');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Chatham Island' ,N'64');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Chile' ,N'56');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'China' ,N'86');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Christmas Island' ,N'618');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cocos-Keeling Islands' ,N'61');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Colombia' ,N'57');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Comoros' ,N'269');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Congo' ,N'242');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cook Islands' ,N'682');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Costa Rica' ,N'506');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Croatia' ,N'385');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cuba' ,N'53119');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cuba (GuantanamoBay);' ,N'5399');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'CuraÃ§ao' ,N'599');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cyprus' ,N'357');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Czech Republic' ,N'420');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Denmark' ,N'45');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Die Garcia' ,N'246');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Djibouti' ,N'253');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Dominica' ,N'1767');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Dominican Republic' ,N'1809');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'East Timor' ,N'670');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Easter Island' ,N'56');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ecuador' ,N'593');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Egypt' ,N'20');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'ElSalvador' ,N'503');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Equatorial Guinea' ,N'240');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Eritrea' ,N'291');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Estonia' ,N'372');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ethiopia' ,N'251');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Falkland Islands' ,N'500');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Faroe Islands' ,N'298');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Fiji Islands' ,N'679');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Finland' ,N'358');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'France' ,N'33');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'French Antilles' ,N'596');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'French Guiana' ,N'594');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'French Polynesia' ,N'689');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Gabonese Republic' ,N'241');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Gambia' ,N'220');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Georgia' ,N'9958');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Germany' ,N'49');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ghana' ,N'233');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Gibraltar' ,N'350');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Greece' ,N'30');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Greenland' ,N'299');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Grenada' ,N'1473');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guadeloupe' ,N'590');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guam' ,N'1671');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guatemala' ,N'502');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guernsey' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guinea' ,N'224');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guinea-Bissau' ,N'245');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guyana' ,N'592');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Haiti' ,N'509');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Honduras' ,N'504');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Hong Kong' ,N'852');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Hungary' ,N'36');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Iceland' ,N'354');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'India' ,N'91');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Indonesia' ,N'62');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Iran' ,N'98');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Iraq' ,N'964');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ireland ' ,N'353');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Isle Of Man' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Israel' ,N'972');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Italy' ,N'39');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Jamaica' ,N'1876');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Japan' ,N'81');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Jersey' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Jordan' ,N'962');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kazakhstan' ,N'78');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kenya' ,N'254');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kenya' ,N'254');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kiribati' ,N'686');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Korea (North);' ,N'850');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Korea (South);' ,N'82');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kuwait' ,N'965');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kyrgyzstan Republic' ,N'996');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Laos' ,N'856');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Latvia' ,N'3718');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Lebanon' ,N'961');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Lesotho' ,N'266');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Liberia' ,N'23122');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Libya' ,N'218');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Liechtenstein' ,N'423');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Lithuania' ,N'3708');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Luxembourg' ,N'352');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Macao' ,N'853');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Macedonia' ,N'389');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Madagascar' ,N'261');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Malawi' ,N'265');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Malaysia' ,N'60');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Maldives' ,N'960');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mali Republic' ,N'223');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Malta' ,N'356');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Marshall Islands' ,N'6921');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Martinique' ,N'596');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mauritania' ,N'222');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mauritius' ,N'230');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mayotte Island' ,N'269');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mexico' ,N'52');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Micronesia' ,N'6911');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Midway Island' ,N'1808');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Moldova' ,N'373');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Monaco' ,N'377');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Monlia' ,N'976');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Montenegro' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Montserrat' ,N'1664');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Morocco' ,N'212');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mozambique' ,N'258');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Myanmar' ,N'95');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Namibia' ,N'264');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Narno Karabakh' ,N'382');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nauru' ,N'674');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nepal' ,N'977');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Netherlands' ,N'31');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Netherlands Antilles' ,N'599');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nevis' ,N'1869');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'New Caledonia' ,N'687');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'New Zealand' ,N'64');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nicaragua' ,N'505');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Niger' ,N'227');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nigeria' ,N'234');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Niue' ,N'683');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Norfolk Island' ,N'672');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Northern Marianas Islands' ,N'1670');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Norway' ,N'47');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Oman' ,N'968');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Pakistan' ,N'92');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Palau' ,N'680');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Palestinian Settlements' ,N'970');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Panama' ,N'507');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Papua New Guinea' ,N'675');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Paraguay' ,N'595');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Peru' ,N'51');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Philippines' ,N'63');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Pitcairn' ,N'64');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Poland' ,N'48');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Portugal' ,N'351');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Puerto Rico' ,N'1787');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Qatar' ,N'974');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'RÃ©union Island' ,N'262');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Romania' ,N'40');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Russia' ,N'78');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Rwandese Republic' ,N'250');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'SÃ£o TomÃ© and Principe' ,N'239');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Samoa' ,N'685');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'San Marino' ,N'378');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Saudi Arabia' ,N'966');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Senegal' ,N'221');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Serbiaand Montenegro' ,N'38199');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Seychelles Republic' ,N'248');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sierra Leone' ,N'232');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Singapore' ,N'65');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Slovakia Republic' ,N'421');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Slovenia' ,N'386');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Solomon Islands' ,N'677');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Somali' ,N'252');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'South Africa' ,N'27');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Spain' ,N'34');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sri Lanka' ,N'94');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Helena' ,N'290');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Kitts/Nevis' ,N'1869');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Lucia' ,N'1758');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Pierre & Miquelon' ,N'508');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Vincent & Grenadines' ,N'1784');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sudan' ,N'249');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Suriname' ,N'597');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Swaziland' ,N'268');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sweden' ,N'46');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Switzerland' ,N'41');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Syria' ,N'963');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Taiwan' ,N'886');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tajikistan' ,N'9928');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tanzania' ,N'255');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Thailand' ,N'66');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Thuraya' ,N'88216');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tokelau' ,N'690');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tolese Republic' ,N'228');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tonga Islands' ,N'676');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Trinidad & Toba' ,N'1868');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tunisia' ,N'216');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Turkey' ,N'90');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Turkmenistan' ,N'9938');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Turks and Caicos Islands' ,N'1649');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tuvalu' ,N'688');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Uganda' ,N'256');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ukraine' ,N'3808');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'United Arab Emirates' ,N'971');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'United Kingdom' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Uruguay' ,N'598');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'US Virgin Islands' ,N'1340');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'USA' ,N'11');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Uzbekistan' ,N'9988');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Vanuatu' ,N'678');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Vatican City' ,N'39');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Venezuela' ,N'58');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Vietnam' ,N'84');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Wake Island' ,N'808');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Wallisand Futuna Islands' ,N'68119');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Western Samoa' ,N'685');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Western Sahara' ,N'212');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Yemen' ,N'967');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Zambia' ,N'260');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Zanzibar' ,N'255');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Zimbabwe' ,N'2630');




ALTER SEQUENCE public."Banners_Id_seq" RESTART 1;
INSERT INTO public."Banners" ("Url","IsDeleted") VALUES
	 ('http://parties.com/PleasureDome.jpg',false),
	 ('http://parties.com/Fantasia.png',false),
	 ('http://parties.com/Ecology.jpg',false),
	 ('http://parties.com/MayDay.jpg',false),
	 ('http://parties.com/FieldOfDreams.png',false),
	 ('http://parties.com/SmurfVillage.jpg',false),
	 ('http://parties.com/JurasicPark.jpg',false);
	

	
ALTER SEQUENCE public."Employees_Id_seq" RESTART 1;
INSERT INTO public."Employees" ("LocaleId","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","CountrySettingId", "Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,random() * 8 + 8, 'Employee','A',NULL,'0412 234 567','info@JeremyThompson.Net',1715,1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Employees" ("LocaleId","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","CountrySettingId", "Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,random() * 8 + 8, 'Employee','B',NULL,'0412 234 567','info@JeremyThompson.Net',1715,1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Employees" ("LocaleId","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","CountrySettingId", "Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,random() * 8 + 8, 'Employee','C',NULL,'0412 234 567','info@JeremyThompson.Net',1715,1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Employees" ("LocaleId","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","CountrySettingId", "Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,random() * 8 + 8, 'Employee','D',NULL,'0412 234 567','info@JeremyThompson.Net',1715,1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Employees" ("LocaleId","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","CountrySettingId", "Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,random() * 8 + 8, 'Employee','E',NULL,'0412 234 567','info@JeremyThompson.Net',1715,1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Employees" ("LocaleId","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","CountrySettingId", "Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,random() * 8 + 8, 'Employee','F',NULL,'0412 234 567','info@JeremyThompson.Net',1715,1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);

	
	

ALTER SEQUENCE public."Events_Id_seq" RESTART 1;	
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1, 'Event','Address','2022-01-01 00:00:00+11','2022-01-01 00:00:00+11',15, 10, true,1,NULL,'2022-01-01 00:00:00+11',NULL);

INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Unity (NYE make up party)','Metropolis, North Sydney','2022-01-08','2022-01-08',25,3153, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Night of the living apple heads','Carpark behind the Saloon Bar, Broadway','2022-01-15','2022-01-15',42,3875, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Cryogenesis','155 Kent St, The Rocks','2022-01-16','2022-01-16',89,1414, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Carl Cox Mania','Same venue as the first space cadet, the old film studio in Alexandria/Mascot.','2022-01-22','2022-01-22',90,4040, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'braindance','324 King St, Newtown','2022-01-25','2022-01-25',38,1648, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'BDO','Moore Park','2022-01-26','2022-01-26',38,1080, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Dune','Bumborah point Rd, Port Botany','2022-01-29','2022-01-29',111,1968, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Free Thought','324 King ST, Newtown','2022-02-12','2022-02-12',100,4349, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'High Times','Bay 33, 33 Bayswater Rd, Kings Cross','2022-02-17','2022-02-17',88,4862, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Heaven',' Metropolis, North Sydney','2022-03-05','2022-03-05',114,1157, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'B''day','201 Elizabeth Street, Sydney','2022-03-19','2022-03-19',36,1416, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Alphebet soup','Alexandria','2022-03-26','2022-03-26',62,4157, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Prodigy 5 The Beehive','Warehouse, Footbridge Boulevard, Homebush Bay - Add more description','2022-04-02','2022-04-02',44,4473, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Platform 94 recovery','Mortuary','2022-04-10','2022-04-10',25,1632, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Astral Flight','carpark behind the Saloon Bar','2022-04-16','2022-04-16',43,417, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Tribal - The Last Dance','Was this one Alexandria or down at Kernel/Botany?','2022-04-23','2022-04-23',26,2051, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Bonzai','carpark behind the Saloon Bar','2022-04-30','2022-04-30',114,253, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Mayday','State Sports Centre, Homebush','2022-05-21','2022-05-21',49,1887, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Space Cadet 3','warehouse on Botany Rd, Alexandria, just near the Grafitti Hall Of Fame','2022-05-28','2022-05-28',33,3133, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Sproket (recovery)','Grafitti Hall of Fame','2022-05-29','2022-05-29',23,1503, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'The Strawberry Patch','GHOF','2022-06-04','2022-06-04',33,2999, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'The Prodigy','Zoom - Oxford St Darlinghurst','2022-06-10','2022-06-10',36,1714, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Roger Ramjet','HardCore Café','2022-06-18','2022-06-18',110,1987, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Zero 1  U/18','DeJa-Vu 252 Pitt St, Sydney','2022-06-27','2022-06-27',103,1735, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Tribal 2 years on DJ Yellow','Ricketty St next to the Alexandria Canal','2022-07-02','2022-07-02',59,1507, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Zero 2 U/18','DeJa-Vu 252 Pitt St, Sydney','2022-07-04','2022-07-04',59,1681, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Moove',' The Teachers Club on Bathurst St','2022-07-09','2022-07-09',50,1079, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Pilgrin','Rooftop','2022-07-15','2022-07-15',59,4036, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Itchy & Scratchy',' Ashfield','2022-07-16','2022-07-16',76,1891, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Smurf Village 1','Hardcore Cafe, wicked tent','2022-08-06','2022-08-06',40,1979, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Transcendence','Agincourt Hotel, Harris St Ultimo','2022-08-12','2022-08-12',100,3770, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Gatorave','Canberra?','2022-08-13','2022-08-13',56,3396, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Colossuss','State Sports Centre, Homebush','2022-08-20','2022-08-20',99,3516, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'cloud 9','Kingshead Tavern','2022-08-26','2022-08-26',25,1207, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Jurassic Rave','Agincourt / Hardcore Café','2022-08-27','2022-08-27',75,1720, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Odyssey','Outdoors ANU (Australian National University )Fellows Oval, Canberra','2022-09-09','2022-09-09',120,3338, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Peak','carpark off Parammata Rd, Broadway, underground behind building opposite central','2022-09-10','2022-09-10',82,3960, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Bulb and Away','right next door to the original Sublime club on Pitt St','2022-09-17','2022-09-17',70,1643, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Pleasure Dome 94','111 Airds Rd, Lumeah down the road from the train station at a warehouse','2022-09-24','2022-09-24',31,3831, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Fantazia - The second Sight','Hardcore Café','2022-10-08','2022-10-08',110,2606, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Section 5','block of Flats Strathfield- underground rave - Brenden''s 21st Strathfield','2022-10-15','2022-10-15',69,4445, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Level X','at fitness gym on Paramatta Rd Granville','2022-10-22','2022-10-22',46,873, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Thomas P Heckman - Totem','','2022-11-04','2022-11-04',57,3358, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Free Night at Hardcore Café - Delerious','','2022-11-05','2022-11-05',118,4386, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'K KLass','Zoom Nightclub, 163 Oxford St, Darlinghurst','2022-11-11','2022-11-11',57,1923, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'punos: brings you','Santuary Studio Café, 173 Campbell St Surry Hills','2022-11-13','2022-11-13',99,4315, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Solidarity','Hordern','2022-11-18','2022-11-18',83,2819, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Passion','pub in the city','2022-11-19','2022-11-19',83,982, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Pleasuredome','warehouse down Campbeltown way.','2022-11-24','2022-11-24',21,2265, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Space Cadet 33 1/3','massive factory/warehouse at botany/Alexandria','2022-11-26','2022-11-26',39,3194, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'MDMA','canterbury rd near the bankstown airport.','2022-12-03','2022-12-03',88,2220, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Magik Mountain','katoomba community centre','2022-12-10','2022-12-10',102,4743, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Beyond Reality','','2022-12-16','2022-12-16',27,2475, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Perception','Harris st carpark?','2022-12-17','2022-12-17',33,2669, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Dyewitness','old court house near Taylor Square, Dalinghurst','2022-12-24','2022-12-24',79,768, true,1,NULL,'2022-01-01 00:00:00+11',NULL);
INSERT INTO public."Events" ("EmployeeId","LocaleId","BannerId","Description","Address","StartTime","EndTime","Price","MaxCapacity","SendReminder","UserId","ModifiedBy","DateCreated","DateModified") VALUES (random() * 5 + 1,random() * 2 + 1, random() * 6 + 1,'Prodigy 6 Rave Paragon','Warehouse near Rosehill Racecourse','2022-12-31','2022-12-31',87,2568, true,1,NULL,'2022-01-01 00:00:00+11',NULL);




ALTER SEQUENCE public."Attendees_Id_seq" RESTART 1;	
--INSERT INTO public."Attendees" ("LocaleId","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","CountrySettingId","Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
--	 (1,random() * 8 + 1, 'Attendee','A',NULL,'0412 234 567','info@JeremyThompson.Net',1, 1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);
	
DO $$
DECLARE 
_id int :=0;
BEGIN
	WHILE _id < 801 LOOP
INSERT INTO public."Attendees" ("LocaleId","TitleSettingId","FirstName","LastName","IndustrySettingId","Phone","Mobile","Email","CountrySettingId","Sex","DateOfBirth","Active","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,random() * 8 + 9 , 'Attendee ' || _id::text, _id::text, (select "Id" from "Settings" s where s."Id" > 1198 and s."Id" < 1700 ORDER BY random() LIMIT 1),
	null, '0412 234 567','info@JeremyThompson.Net', random() * 250 + 1700, random() * 1,'2000-01-01', true,1,NULL,'2022-01-01 00:00:00+11',NULL);
	_id := _id+1;
	END LOOP;
END $$;


ALTER SEQUENCE public."EventAttendees_Id_seq" RESTART 1;	
DO $$
DECLARE _id int :=0;
BEGIN
	WHILE _id < 5000 LOOP
INSERT INTO public."EventAttendees" ("EventId","AttendeeId","InAttendence","Cancelled","SurveyRating") VALUES
	 ( random() * 56 + 1, random() * 800 + 1,random() > 0.5, random() > 0.5, random() * 10);
	_id := _id+1;
	END LOOP;
END $$;



select * from "Settings" ;
select * from "Attendees" ;
select * from "Events";
select * from "EventAttendees";
select * from "Employees";
select * from "Banners";
select * from "Locales";

--
--select s."SettingProperty", e.* from "Events" e
--inner join "Employees" e2 on e."EmployeeId" = e2."Id" 
--inner join "Settings" s on s."Id" = e2."TitleSettingId";
