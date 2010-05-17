-----------------------------------------------------------------------
--                XML/Ada - An XML suite for Ada95                   --
--                                                                   --
--                       Copyright (C) 2004-2010, AdaCore            --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

with Ada.Strings.Fixed;         use Ada.Strings.Fixed;
with Schema.Validators.Facets;  use Schema.Validators.Facets;
with Sax.Encodings;             use Sax.Encodings;
with Sax.Readers;               use Sax.Readers;
with Sax.Symbols;               use Sax.Symbols;
with Sax.Utils;                 use Sax.Utils;
with Schema.Date_Time;          use Schema.Date_Time;
with Schema.Decimal;            use Schema.Decimal;
with Schema.Readers;            use Schema.Readers;
with Unicode.CES;               use Unicode, Unicode.CES;
with Unicode.Names.Basic_Latin; use Unicode.Names.Basic_Latin;

package body Schema.Validators.Simple_Types is

   B64 : constant array (Unicode_Char range 32 .. 128) of Boolean :=
      (Character'Pos ('A') .. Character'Pos ('Z') => True,
       Character'Pos ('a') .. Character'Pos ('z') => True,
       Character'Pos ('0') .. Character'Pos ('9') => True,
       Character'Pos ('+') => True,
       Character'Pos ('/') => True,
       others => False);
   B04 : constant array (Unicode_Char range 32 .. 128) of Boolean :=
      (Character'Pos ('A') => True,
       Character'Pos ('Q') => True,
       Character'Pos ('g') => True,
       Character'Pos ('w') => True,
       others => False);
   B16 : constant array (Unicode_Char range 32 .. 128) of Boolean :=
      (Character'Pos ('A') => True,
       Character'Pos ('E') => True,
       Character'Pos ('I') => True,
       Character'Pos ('M') => True,
       Character'Pos ('Q') => True,
       Character'Pos ('U') => True,
       Character'Pos ('Y') => True,
       Character'Pos ('c') => True,
       Character'Pos ('g') => True,
       Character'Pos ('k') => True,
       Character'Pos ('o') => True,
       Character'Pos ('s') => True,
       Character'Pos ('w') => True,
       Character'Pos ('0') => True,
       Character'Pos ('4') => True,
       Character'Pos ('8') => True,
       others => False);
   --  Whether the character matches the Base64Binary definitions

   type XML_Float_Kind is (Plus_Infinity, Minus_Infinity, NaN, Standard_Float);
   type XML_Float (Kind : XML_Float_Kind := NaN) is record
      case Kind is
         when Standard_Float =>
            Value : Long_Long_Float;
         when others =>
            null;
      end case;
   end record;

   function "<=" (F1, F2 : XML_Float) return Boolean;
   function "<" (F1, F2 : XML_Float) return Boolean;
   function ">=" (F1, F2 : XML_Float) return Boolean;
   function ">" (F1, F2 : XML_Float) return Boolean;
   function Image (Value : XML_Float) return String;
   function Value
     (Reader : access Abstract_Validation_Reader'Class;
      Str    : String) return XML_Float;
   function Value
     (Reader : access Abstract_Validation_Reader'Class;
      Str    : String) return Long_Long_Integer;
   function Value
     (Reader : access Abstract_Validation_Reader'Class;
      Ch     : Byte_Sequence) return Boolean;
   --  Return the float stored in Str (including +INF, -INF)

   ----------
   -- "<=" --
   ----------

   function "<=" (F1, F2 : XML_Float) return Boolean is
   begin
      case F1.Kind is
         when NaN =>
            return False;
         when Plus_Infinity =>
            return False;
         when Minus_Infinity =>
            return True;
         when Standard_Float =>
            case F2.Kind is
               when NaN =>
                  return False;
               when Plus_Infinity =>
                  return True;
               when Minus_Infinity =>
                  return False;
               when Standard_Float =>
                  return F1.Value <= F2.Value;
            end case;
      end case;
   end "<=";

   ----------
   -- ">=" --
   ----------

   function ">=" (F1, F2 : XML_Float) return Boolean is
   begin
      return not (F1 < F2);
   end ">=";

   ---------
   -- ">" --
   ---------

   function ">" (F1, F2 : XML_Float) return Boolean is
   begin
      return not (F1 <= F2);
   end ">";

   ---------
   -- "<" --
   ---------

   function "<" (F1, F2 : XML_Float) return Boolean is
   begin
      case F1.Kind is
         when NaN =>
            return False;
         when Plus_Infinity =>
            return False;
         when Minus_Infinity =>
            return True;
         when Standard_Float =>
            case F2.Kind is
               when NaN =>
                  return False;
               when Plus_Infinity =>
                  return True;
               when Minus_Infinity =>
                  return False;
               when Standard_Float =>
                  return F1.Value < F2.Value;
            end case;
      end case;
   end "<";

   -----------
   -- Value --
   -----------

   function Value
     (Reader : access Abstract_Validation_Reader'Class;
      Str    : String) return Long_Long_Integer
   is
      pragma Unreferenced (Reader);
   begin
      return Long_Long_Integer'Value (Str);
   end Value;

   -----------
   -- Value --
   -----------

   function Value
     (Reader : access Abstract_Validation_Reader'Class;
      Str    : String) return XML_Float
   is
      pragma Unreferenced (Reader);
   begin
      if Str = "NaN" then
         return XML_Float'(Kind => NaN);
      elsif Str = "INF" or else Str = "+INF" then
         return XML_Float'(Kind => Plus_Infinity);
      elsif Str = "-INF" then
         return XML_Float'(Kind => Minus_Infinity);
      else
         return XML_Float'(Kind  => Standard_Float,
                           Value => Long_Long_Float'Value (Str));
      end if;
   end Value;

   -----------
   -- Image --
   -----------

   function Image (Value : XML_Float) return String is
   begin
      case Value.Kind is
         when NaN =>
            return "NaN";
         when Plus_Infinity =>
            return "INF";
         when Minus_Infinity =>
            return "-INF";
         when Standard_Float =>
            declare
               Str : constant String := Long_Long_Float'Image (Value.Value);
               E   : constant Integer := Index (Str, "E");
            begin
               if E < Str'First then
                  for J in reverse Str'Range loop
                     if Str (J) /= '0' then
                        return Str (Str'First .. J);
                     end if;
                  end loop;
               else
                  for J in reverse Str'First .. E - 1 loop
                     if Str (J) /= '0' then
                        return Str (Str'First .. J) & Str (E .. Str'Last);
                     end if;
                  end loop;
               end if;
               return Str;
            end;
      end case;
   end Image;

   ------------------------------------
   --  Facets used for ranged values --
   ------------------------------------

   generic
      Type_Name : String;
      type T is private;
      with function Value
        (Reader : access Abstract_Validation_Reader'Class;
         Ch     : Unicode.CES.Byte_Sequence) return T is <>;
      with function Image (T1 : T) return Unicode.CES.Byte_Sequence is <>;
      with function "=" (T1, T2 : T) return Boolean is <>;
      with function "<=" (T1, T2 : T) return Boolean is <>;
      with function "<" (T1, T2 : T) return Boolean is <>;
      with function ">=" (T1, T2 : T) return Boolean is <>;
      with function ">" (T1, T2 : T) return Boolean is <>;
   package Generic_Range_Facets is
      type Range_Facets_Description is new Common_Facets_Description with
         record
            Max_Inclusive  : T;
            Min_Inclusive  : T;
            Max_Exclusive  : T;
            Min_Exclusive  : T;
         end record;

      function Equal
        (Facet  : Range_Facets_Description;
         Reader : access Abstract_Validation_Reader'Class;
         Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean;
      procedure Add_Facet
        (Facets      : in out Range_Facets_Description;
         Reader      : access Abstract_Validation_Reader'Class;
         Facet_Name  : Unicode.CES.Byte_Sequence;
         Facet_Value : Unicode.CES.Byte_Sequence;
         Applied     : out Boolean);
      procedure Check_Facet
        (Facets     : in out Range_Facets_Description;
         Reader     : access Abstract_Validation_Reader'Class;
         Node_Value : Unicode.CES.Byte_Sequence;
         Mask       : in out Facets_Mask);
      procedure Copy
        (From : Range_Facets_Description;
         To   : in out Facets_Description_Record'Class);
      --  See doc for inherited subprograms
   end Generic_Range_Facets;

   ------------------------------------
   --  Facets used for length values --
   ------------------------------------

   generic
      with function Get_Length
        (Value : Unicode.CES.Byte_Sequence) return Natural;
   package Length_Facets is
      type Length_Facets_Description is new Common_Facets_Description with
         record
            Length      : Natural := Natural'Last;
            Min_Length  : Natural := 0;
            Max_Length  : Natural := Natural'Last;
         end record;
   private
      procedure Add_Facet
        (Facets      : in out Length_Facets_Description;
         Reader      : access Abstract_Validation_Reader'Class;
         Facet_Name  : Unicode.CES.Byte_Sequence;
         Facet_Value : Unicode.CES.Byte_Sequence;
         Applied     : out Boolean);
      procedure Check_Facet
        (Facets : in out Length_Facets_Description;
         Reader : access Abstract_Validation_Reader'Class;
         Value  : Unicode.CES.Byte_Sequence;
         Mask   : in out Facets_Mask);
      procedure Copy
        (From : Length_Facets_Description;
         To   : in out Facets_Description_Record'Class);
   end Length_Facets;

   --  For QName, length facets always match (4.3.1.3)

   type Always_Match_Length_Facets_Description
     is new Common_Facets_Description with null record;
   procedure Add_Facet
     (Facets      : in out Always_Match_Length_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Applied     : out Boolean);

   -----------------------
   -- Generic validator --
   -----------------------
   --  This validator can be used to implement several other validators
   --  when they all delegate their work to their facets checker.
   --  It can be used for all types which have no children nodes.

   generic
      type Facets_Type is new Common_Facets_Description with private;
   package Generic_Simple_Validator is
      type Facets_Type_Access is access all Facets_Type;
      type Validator_Record is new Any_Simple_XML_Validator_Record
         with null record;
      type Validator is access all Validator_Record'Class;

      procedure Validate_Characters
        (Validator     : access Validator_Record;
         Reader        : access Abstract_Validation_Reader'Class;
         Ch            : Unicode.CES.Byte_Sequence;
         Empty_Element : Boolean;
         Mask          : in out Facets_Mask);
      procedure Add_Facet
        (Validator   : access Validator_Record;
         Reader      : access Abstract_Validation_Reader'Class;
         Facet_Name  : Unicode.CES.Byte_Sequence;
         Facet_Value : Unicode.CES.Byte_Sequence);
      function Get_Facets
        (Validator : access Validator_Record;
         Reader    : access Abstract_Validation_Reader'Class)
         return Facets_Description;
      --  See doc for inherited subprograms
   end Generic_Simple_Validator;

   --------------------------
   -- Generic_Range_Facets --
   --------------------------

   package body Generic_Range_Facets is

      -----------
      -- Equal --
      -----------

      function Equal
        (Facet : Range_Facets_Description;
         Reader : access Abstract_Validation_Reader'Class;
         Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean
      is
         pragma Unreferenced (Facet);
         V1 : constant T := Value (Reader, Value1);
         V2 : constant T := Value (Reader, Value2);
      begin
         return V1 = V2;
      end Equal;

      ----------
      -- Copy --
      ----------

      procedure Copy
        (From : Range_Facets_Description;
         To   : in out Facets_Description_Record'Class)
      is
      begin
         Copy (From => Common_Facets_Description (From), To => To);
         Range_Facets_Description (To).Max_Inclusive := From.Max_Inclusive;
         Range_Facets_Description (To).Min_Inclusive := From.Min_Inclusive;
         Range_Facets_Description (To).Max_Exclusive := From.Max_Exclusive;
         Range_Facets_Description (To).Min_Exclusive := From.Min_Exclusive;
      end Copy;

      -----------------
      -- Check_Facet --
      -----------------

      procedure Check_Facet
        (Facets     : in out Range_Facets_Description;
         Reader     : access Abstract_Validation_Reader'Class;
         Node_Value : Unicode.CES.Byte_Sequence;
         Mask       : in out Facets_Mask)
      is
         Val : T;
      begin
         Val := Value (Reader, Node_Value);

         Check_Facet
           (Common_Facets_Description (Facets), Reader, Node_Value, Mask);

         if Facets.Mask (Facet_Max_Exclusive)
           and Mask (Facet_Max_Exclusive)
         then
            Mask (Facet_Max_Exclusive) := False;
            if Facets.Max_Exclusive <= Val then
               Validation_Error
                 (Reader,
                  '#' & Node_Value & " is greater than maxExclusive ("
                  & Image (Facets.Max_Exclusive) & ")");
            end if;
         end if;

         if Facets.Mask (Facet_Max_Inclusive)
           and Mask (Facet_Max_Inclusive)
         then
            Mask (Facet_Max_Inclusive) := False;
            if Facets.Max_Inclusive < Val then
               Validation_Error
                 (Reader,
                  '#' & Node_Value & " is greater than maxInclusive ("
                  & Image (Facets.Max_Inclusive) & ")");
            end if;
         end if;

         if Facets.Mask (Facet_Min_Inclusive)
           and Mask (Facet_Min_Inclusive)
         then
            Mask (Facet_Min_Inclusive) := False;
            if Facets.Min_Inclusive > Val then
               Validation_Error
                 (Reader,
                  '#' & Node_Value & " is smaller than minInclusive ("
                  & Image (Facets.Min_Inclusive) & ")");
            end if;
         end if;

         if Facets.Mask (Facet_Min_Exclusive)
           and Mask (Facet_Min_Exclusive)
         then
            Mask (Facet_Min_Exclusive) := False;
            if Facets.Min_Exclusive >= Val then
               Validation_Error
                 (Reader,
                  '#' & Node_Value & " is smaller than minExclusive ("
                  & Image (Facets.Min_Exclusive) & ")");
            end if;
         end if;

      exception
         when Constraint_Error =>
            Validation_Error
              (Reader, "#Invalid " & Type_Name & ": """ & Node_Value & """");
      end Check_Facet;

      ---------------
      -- Add_Facet --
      ---------------

      procedure Add_Facet
        (Facets      : in out Range_Facets_Description;
         Reader      : access Abstract_Validation_Reader'Class;
         Facet_Name  : Unicode.CES.Byte_Sequence;
         Facet_Value : Unicode.CES.Byte_Sequence;
         Applied     : out Boolean) is
      begin
         Add_Facet
           (Common_Facets_Description (Facets), Reader,
            Facet_Name, Facet_Value, Applied);
         if Applied then
            null;
         elsif Facet_Name = "maxInclusive" then
            Facets.Max_Inclusive := Value (Reader, Facet_Value);
            Facets.Mask (Facet_Max_Inclusive) := True;
            Applied := True;
         elsif Facet_Name = "maxExclusive" then
            Facets.Max_Exclusive := Value (Reader, Facet_Value);
            Facets.Mask (Facet_Max_Exclusive) := True;
            Applied := True;
         elsif Facet_Name = "minInclusive" then
            Facets.Min_Inclusive := Value (Reader, Facet_Value);
            Facets.Mask (Facet_Min_Inclusive) := True;
            Applied := True;
         elsif Facet_Name = "minExclusive" then
            Facets.Min_Exclusive := Value (Reader, Facet_Value);
            Facets.Mask (Facet_Min_Exclusive) := True;
            Applied := True;
         else
            Applied := False;
         end if;

      exception
         when Constraint_Error =>
            Validation_Error
              (Reader,
               "#Invalid " & Facet_Name & ": """ & Facet_Value & """");
      end Add_Facet;
   end Generic_Range_Facets;

   -------------------
   -- Length_Facets --
   -------------------

   package body Length_Facets is

      ----------
      -- Copy --
      ----------

      procedure Copy
        (From : Length_Facets_Description;
         To   : in out Facets_Description_Record'Class) is
      begin
         Copy (Common_Facets_Description (From), To);
         Length_Facets_Description (To).Length     := From.Length;
         Length_Facets_Description (To).Min_Length := From.Min_Length;
         Length_Facets_Description (To).Max_Length := From.Max_Length;
      end Copy;

      ---------------
      -- Add_Facet --
      ---------------

      procedure Add_Facet
        (Facets      : in out Length_Facets_Description;
         Reader      : access Abstract_Validation_Reader'Class;
         Facet_Name  : Unicode.CES.Byte_Sequence;
         Facet_Value : Unicode.CES.Byte_Sequence;
         Applied     : out Boolean) is
      begin
         Add_Facet (Common_Facets_Description (Facets), Reader, Facet_Name,
                    Facet_Value, Applied);
         if Applied then
            null;
         elsif Facet_Name = "length" then
            Facets.Length := Integer'Value (Facet_Value);
            Facets.Mask (Facet_Length) := True;
            Applied := True;
         elsif Facet_Name = "minLength" then
            Facets.Min_Length := Integer'Value (Facet_Value);
            Facets.Mask (Facet_Min_Length) := True;
            Applied := True;
         elsif Facet_Name = "maxLength" then
            Facets.Max_Length := Integer'Value (Facet_Value);
            Facets.Mask (Facet_Max_Length) := True;
            Applied := True;
         else
            Applied := False;
         end if;
      end Add_Facet;

      -----------------
      -- Check_Facet --
      -----------------

      procedure Check_Facet
        (Facets : in out Length_Facets_Description;
         Reader : access Abstract_Validation_Reader'Class;
         Value  : Unicode.CES.Byte_Sequence;
         Mask   : in out Facets_Mask)
      is
         Length : Integer;
      begin
         if Facets.Mask (Facet_Length)
           or else Facets.Mask (Facet_Min_Length)
           or else Facets.Mask (Facet_Max_Length)
         then
            Length := Get_Length (Value);

            if Facets.Mask (Facet_Length) and Mask (Facet_Length) then
               Mask (Facet_Length) := False;
               if Facets.Length /= Length then
                  Validation_Error
                    (Reader,
                     "#Invalid length, must be"
                     & Integer'Image (Facets.Length) & " characters");
               end if;
            end if;

            if Facets.Mask (Facet_Min_Length) and Mask (Facet_Min_Length) then
               Mask (Facet_Min_Length) := False;
               if Length < Facets.Min_Length then
                  Validation_Error (Reader,
                                    "#String is too short, minimum length is"
                                    & Integer'Image (Facets.Min_Length)
                                    & " characters");
               end if;
            end if;

            if Facets.Mask (Facet_Max_Length) and Mask (Facet_Max_Length) then
               Mask (Facet_Max_Length) := False;
               if Length > Facets.Max_Length then
                  Validation_Error (Reader,
                                    "#String too long, maximum length is"
                                    & Integer'Image (Facets.Max_Length)
                                    & " characters");
               end if;
            end if;
         end if;

         Check_Facet (Common_Facets_Description (Facets), Reader, Value, Mask);
      end Check_Facet;
   end Length_Facets;

   ---------------
   -- Add_Facet --
   ---------------

   procedure Add_Facet
     (Facets      : in out Always_Match_Length_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Applied     : out Boolean)
   is
   begin
      Add_Facet (Common_Facets_Description (Facets), Reader, Facet_Name,
                 Facet_Value, Applied);
      if Applied
        or else Facet_Name = "length"
        or else Facet_Name = "minLength"
        or else Facet_Name = "maxLength"
      then
         Applied := True;
      else
         Applied := False;
      end if;
   end Add_Facet;

   ------------------------------
   -- Generic_Simple_Validator --
   ------------------------------

   package body Generic_Simple_Validator is

      -------------------------
      -- Validate_Characters --
      -------------------------

      procedure Validate_Characters
        (Validator     : access Validator_Record;
         Reader        : access Abstract_Validation_Reader'Class;
         Ch            : Unicode.CES.Byte_Sequence;
         Empty_Element : Boolean;
         Mask          : in out Facets_Mask)
      is
         pragma Unreferenced (Empty_Element);
      begin
         if Debug then
            Debug_Output ("Validate_Characters " & Get_Name (Validator));
         end if;

         Check_Id (Reader, Validator, Ch);
         Check_Facet (Get_Facets (Validator, Reader).all, Reader, Ch, Mask);
      end Validate_Characters;

      ---------------
      -- Add_Facet --
      ---------------

      procedure Add_Facet
        (Validator   : access Validator_Record;
         Reader      : access Abstract_Validation_Reader'Class;
         Facet_Name  : Unicode.CES.Byte_Sequence;
         Facet_Value : Unicode.CES.Byte_Sequence)
      is
         Applies : Boolean;
      begin
         Add_Facet
           (Get_Facets (Validator, Reader).all, Reader,
            Facet_Name, Facet_Value, Applies);
         if not Applies then
            Validation_Error (Reader, "#Invalid facet: " & Facet_Name);
         end if;
      end Add_Facet;

      ----------------
      -- Get_Facets --
      ----------------

      function Get_Facets
        (Validator : access Validator_Record;
         Reader    : access Abstract_Validation_Reader'Class)
         return Facets_Description
      is
         pragma Unreferenced (Reader);
      begin
         if Validator.Facets = null then
            Validator.Facets := new Facets_Type;
         end if;
         return Facets_Description (Validator.Facets);
      end Get_Facets;

   end Generic_Simple_Validator;

   ------------------
   -- Simple types --
   ------------------

   package Time_Facets_Package is new Generic_Range_Facets ("time", Time_T);
   package Time_Validators is new Generic_Simple_Validator
     (Time_Facets_Package.Range_Facets_Description);

   package Date_Time_Facets_Package is new Generic_Range_Facets
     ("dateTime", Date_Time_T);
   package Date_Time_Validators is new Generic_Simple_Validator
     (Date_Time_Facets_Package.Range_Facets_Description);

   package GDay_Facets_Package is new Generic_Range_Facets
     ("gDay", GDay_T);
   package GDay_Validators is new Generic_Simple_Validator
     (GDay_Facets_Package.Range_Facets_Description);

   package GMonth_Day_Facets_Package is new Generic_Range_Facets
     ("gMonthDay", GMonth_Day_T);
   package GMonth_Day_Validators is new Generic_Simple_Validator
     (GMonth_Day_Facets_Package.Range_Facets_Description);

   package GMonth_Facets_Package is new Generic_Range_Facets
     ("gMonth", GMonth_T);
   package GMonth_Validators is new Generic_Simple_Validator
     (GMonth_Facets_Package.Range_Facets_Description);

   package GYear_Facets_Package is new Generic_Range_Facets
     ("gYear", GYear_T);
   package GYear_Validators is new Generic_Simple_Validator
     (GYear_Facets_Package.Range_Facets_Description);

   package GYear_Month_Facets_Package is new Generic_Range_Facets
     ("gYearMonth", GYear_Month_T);
   package GYear_Month_Validators is new Generic_Simple_Validator
     (GYear_Month_Facets_Package.Range_Facets_Description);

   package Date_Facets_Package is new Generic_Range_Facets
     ("date", Date_T);
   package Date_Validators is new Generic_Simple_Validator
     (Date_Facets_Package.Range_Facets_Description);

   package Duration_Facets_Package is new Generic_Range_Facets
     ("duration", Duration_T);
   package Duration_Validators is new Generic_Simple_Validator
     (Duration_Facets_Package.Range_Facets_Description);

   package Float_Facets_Package is new Generic_Range_Facets
     ("float", XML_Float, Value, Image);
   type Float_Facets_Description is
     new Float_Facets_Package.Range_Facets_Description with null record;
   procedure Check_Facet
     (Facets      : in out Float_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Mask        : in out Facets_Mask);
   package Float_Validators is new Generic_Simple_Validator
     (Float_Facets_Description);

   package Decimal_Facets_Package is new Generic_Range_Facets
     ("decimal", Arbitrary_Precision_Number, Value_No_Exponent, Image);
   type Decimal_Facets_Description is new
     Decimal_Facets_Package.Range_Facets_Description with
      record
         Total_Digits    : Positive := Positive'Last;
         Fraction_Digits : Natural := Natural'Last;
      end record;
   procedure Add_Facet
     (Facets      : in out Decimal_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Applied     : out Boolean);
   procedure Copy
     (From : Decimal_Facets_Description;
      To   : in out Facets_Description_Record'Class);
   procedure Check_Facet
     (Facets      : in out Decimal_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Mask        : in out Facets_Mask);
   package Decimal_Validators is new Generic_Simple_Validator
     (Decimal_Facets_Description);

   package Integer_Facets_Package is new Generic_Range_Facets
     ("integer", Long_Long_Integer, Value, Long_Long_Integer'Image);
   type Integer_Facets_Description is new
     Integer_Facets_Package.Range_Facets_Description
   with record
      Total_Digits    : Positive := Positive'Last;
   end record;
   procedure Copy
     (From : Integer_Facets_Description;
      To   : in out Facets_Description_Record'Class);
   procedure Add_Facet
     (Facets      : in out Integer_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Applied     : out Boolean);
   procedure Check_Facet
     (Facets      : in out Integer_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Mask        : in out Facets_Mask);
   package Integer_Validators is new Generic_Simple_Validator
     (Integer_Facets_Description);

   type Boolean_Validator_Record is new Any_Simple_XML_Validator_Record with
      null record;
   procedure Validate_Characters
     (Validator     : access Boolean_Validator_Record;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask);
   procedure Add_Facet
     (Validator   : access Boolean_Validator_Record;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence);
   function Equal
     (Validator      : access Boolean_Validator_Record;
      Reader         : access Abstract_Validation_Reader'Class;
      Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean;
   --   See doc from inherited subprograms

   ----------------------
   -- String_Validator --
   ----------------------

   function String_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural;
   package String_Facets is new Length_Facets (String_Get_Length);
   package String_Validators is new Generic_Simple_Validator
     (String_Facets.Length_Facets_Description);

   function String_List_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural;
   package String_List_Facets is new Length_Facets (String_List_Get_Length);
   package String_List_Validators is new Generic_Simple_Validator
     (String_List_Facets.Length_Facets_Description);

   function HexBinary_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural;
   package HexBinary_Facets is new Length_Facets (HexBinary_Get_Length);
   package HexBinary_Validators is new Generic_Simple_Validator
     (HexBinary_Facets.Length_Facets_Description);
   type HexBinary_Validator is new HexBinary_Validators.Validator_Record
      with null record;
   procedure Validate_Characters
     (Validator     : access HexBinary_Validator;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask);
   --  See inherited documentation

   function Base64Binary_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural;
   function Is_Valid_Base64Binary
     (Value : Unicode.CES.Byte_Sequence) return Boolean;
   package Base64Binary_Facets is new Length_Facets (Base64Binary_Get_Length);
   package Base64Binary_Validators is new Generic_Simple_Validator
     (Base64Binary_Facets.Length_Facets_Description);

   type ID_Validator
     is new String_Validators.Validator_Record with null record;
   function Is_ID (Validator : ID_Validator) return Boolean;

   package QName_Validators is new Generic_Simple_Validator
     (Always_Match_Length_Facets_Description);
   type QName_Validator
     is new QName_Validators.Validator_Record with null record;
   procedure Validate_Characters
     (Validator     : access QName_Validator;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask);

   -------------------------
   -- Validate_Characters --
   -------------------------

   procedure Validate_Characters
     (Validator     : access QName_Validator;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask)
   is
      pragma Unreferenced (Validator, Empty_Element, Mask);
      Pos : Integer;
      NS  : XML_NS;
   begin
      if not Is_Valid_QName (Ch) then
         Validation_Error (Reader, "#Invalid QName: """ & Ch & '"');
      end if;

      Pos := Ada.Strings.Fixed.Index (Ch, ":");
      if Pos >= Ch'First then
         --  Check whether the namespace is valid
         Get_Namespace_From_Prefix
           (Handler => Validating_Reader (Reader.all),
            Prefix  => Ch (Ch'First .. Pos - 1),
            NS      => NS);
         if NS = No_XML_NS or else Get_URI (NS) = Reader.Xmlns then
            Validation_Error (Reader,
                              "#No corresponding namespace in scope for """
                              & Ch (Ch'First .. Pos - 1) & '"');
         end if;
      end if;
   end Validate_Characters;

   -------------------------
   -- Validate_Characters --
   -------------------------

   procedure Validate_Characters
     (Validator     : access HexBinary_Validator;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask) is
   begin
      if Sax.Encodings.Encoding.Length (Ch) mod 2 /= 0 then
         Validation_Error
           (Reader, "#HexBinary length must be an even number of characters");
      end if;
      HexBinary_Validators.Validate_Characters
        (HexBinary_Validators.Validator_Record (Validator.all)'Access,
         Reader, Ch, Empty_Element, Mask);
   end Validate_Characters;

   -----------------------
   -- Check_Replacement --
   -----------------------

   procedure Check_Replacement
     (Validator       : access Any_Simple_XML_Validator_Record;
      Element         : XML_Element;
      Typ             : XML_Type;
      Valid           : out Boolean;
      Had_Restriction : in out Boolean;
      Had_Extension   : in out Boolean)
   is
      pragma Unreferenced (Validator, Element, Had_Restriction, Had_Extension);
   begin
      Valid := Is_Wildcard (Get_Validator (Typ))
        or else
          Get_Validator (Typ).all in Any_Simple_XML_Validator_Record'Class;
      Had_Restriction := True;
   end Check_Replacement;

   -----------------------
   -- Get_Mixed_Content --
   -----------------------

   function Get_Mixed_Content
     (Validator : access Any_Simple_XML_Validator_Record) return Boolean
   is
      pragma Unreferenced (Validator);
   begin
      return True;
   end Get_Mixed_Content;

   -----------
   -- Is_ID --
   -----------

   function Is_ID (Validator : ID_Validator) return Boolean is
      pragma Unreferenced (Validator);
   begin
      return True;
   end Is_ID;

   ----------
   -- Copy --
   ----------

   procedure Copy
     (From : Integer_Facets_Description;
      To   : in out Facets_Description_Record'Class) is
   begin
      Integer_Facets_Package.Copy
        (Integer_Facets_Package.Range_Facets_Description (From), To);
      Integer_Facets_Description (To).Total_Digits := From.Total_Digits;
   end Copy;

   -----------------
   -- Check_Facet --
   -----------------

   procedure Check_Facet
     (Facets      : in out Integer_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Mask        : in out Facets_Mask)
   is
      use Integer_Facets_Package;
   begin
      if Facets.Mask (Facet_Total_Digits) and Mask (Facet_Total_Digits) then
         Mask (Facet_Total_Digits) := False;
         if Facet_Value'Length > Facets.Total_Digits then
            Validation_Error
              (Reader, "#The maximum number of digits is"
               & Integer'Image (Facets.Total_Digits));
         end if;
      end if;

      Check_Facet
        (Range_Facets_Description (Facets), Reader, Facet_Value, Mask);
   end Check_Facet;

   ---------------
   -- Add_Facet --
   ---------------

   procedure Add_Facet
     (Facets      : in out Integer_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Applied     : out Boolean)
   is
      use Integer_Facets_Package;
      Val : Integer;
   begin
      Add_Facet
        (Integer_Facets_Package.Range_Facets_Description (Facets),
         Reader, Facet_Name, Facet_Value, Applied);
      if Applied then
         null;
      elsif Facet_Name = "totalDigits" then
         Facets.Total_Digits := Integer'Value (Facet_Value);
         Facets.Mask (Facet_Total_Digits) := True;
         Applied := True;
      elsif Facet_Name = "fractionDigits" then
         Val := Integer'Value (Facet_Value);
         if Val /= 0 then
            Validation_Error
              (Reader, "#fractionDigits must be 0 for integers");
         end if;
         Applied := True;
      else
         Applied := False;
      end if;
   exception
      when Constraint_Error =>
         Applied := False;
   end Add_Facet;

   ---------------
   -- Add_Facet --
   ---------------

   procedure Add_Facet
     (Facets      : in out Decimal_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Applied     : out Boolean)
   is
      use Decimal_Facets_Package;
   begin
      Add_Facet
        (Decimal_Facets_Package.Range_Facets_Description (Facets), Reader,
         Facet_Name, Facet_Value, Applied);
      if Applied then
         null;
      elsif Facet_Name = "totalDigits" then
         Facets.Total_Digits := Integer'Value (Facet_Value);
         Facets.Mask (Facet_Total_Digits) := True;
         if Facets.Mask (Facet_Fraction_Digits)
           and then Facets.Fraction_Digits > Facets.Total_Digits
         then
            Validation_Error
              (Reader, "#fractionDigits cannot be greater than totalDigits");
         end if;

         Applied := True;
      elsif Facet_Name = "fractionDigits" then
         Facets.Fraction_Digits := Integer'Value (Facet_Value);
         if Facets.Mask (Facet_Total_Digits)
           and then Facets.Fraction_Digits > Facets.Total_Digits
         then
            Validation_Error
              (Reader, "#fractionDigits cannot be greater than totalDigits");
         end if;
         Applied := True;
      else
         Applied := False;
      end if;
   exception
      when Constraint_Error =>
         if Debug then
            Debug_Output ("Constraint_Error when setting facet "
                          & Facet_Name & " " & Facet_Value);
         end if;
         Applied := False;
   end Add_Facet;

   ----------
   -- Copy --
   ----------

   procedure Copy
     (From : Decimal_Facets_Description;
      To   : in out Facets_Description_Record'Class) is
   begin
      Decimal_Facets_Package.Copy
        (Decimal_Facets_Package.Range_Facets_Description (From), To);
      Decimal_Facets_Description (To).Total_Digits := From.Total_Digits;
      Decimal_Facets_Description (To).Fraction_Digits := From.Fraction_Digits;
   end Copy;

   -----------------
   -- Check_Facet --
   -----------------

   procedure Check_Facet
     (Facets      : in out Decimal_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Mask        : in out Facets_Mask)
   is
      use Decimal_Facets_Package;
   begin
      Check_Digits
        (Reader,
         Value_No_Exponent (Reader, Facet_Value), Facets.Fraction_Digits,
         Facets.Total_Digits);
      Check_Facet
        (Range_Facets_Description (Facets), Reader, Facet_Value, Mask);
   end Check_Facet;

   -----------
   -- Value --
   -----------

   function Value
     (Reader : access Abstract_Validation_Reader'Class;
      Ch     : Byte_Sequence) return Boolean
   is
      First : Integer := Ch'First;
      Index : Integer;
      C     : Unicode_Char;
      Result : Boolean;
   begin
      --  Skip leading spaces
      while First <= Ch'Last loop
         Index := First;
         Encoding.Read (Ch, First, C);
         exit when not Is_White_Space (C);
      end loop;

      if C = Digit_Zero or C = Digit_One then
         Result := C = Digit_One;
         if First <= Ch'Last then
            Encoding.Read (Ch, First, C);
         end if;

      elsif Index + True_Sequence'Length - 1 <= Ch'Last
        and then Ch (Index .. Index + True_Sequence'Length - 1) = True_Sequence
      then
         First := Index + True_Sequence'Length;
         Result := True;

      elsif Index + False_Sequence'Length - 1 <= Ch'Last
        and then Ch (Index .. Index + False_Sequence'Length - 1) =
          False_Sequence
      then
         First := Index + False_Sequence'Length;
         Result := False;

      else
         Validation_Error
           (Reader, "#Invalid value for boolean type: """ & Ch & """");
      end if;

      --  Skip trailing spaces

      while First <= Ch'Last loop
         Encoding.Read (Ch, First, C);
         if not Is_White_Space (C) then
            Validation_Error
              (Reader, "#Invalid value for boolean type: """ & Ch & """");
         end if;
      end loop;

      return Result;
   end Value;

   -----------
   -- Equal --
   -----------

   function Equal
     (Validator      : access Boolean_Validator_Record;
      Reader         : access Abstract_Validation_Reader'Class;
      Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean
   is
      pragma Unreferenced (Validator);
      V1 : constant Boolean := Value (Reader, Value1);
      V2 : constant Boolean := Value (Reader, Value2);
   begin
      return V1 = V2;
   end Equal;

   -------------------------
   -- Validate_Characters --
   -------------------------

   procedure Validate_Characters
     (Validator     : access Boolean_Validator_Record;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask)
   is
      Val : Boolean;
      pragma Unreferenced (Empty_Element, Val);
   begin
      if Debug then
         Debug_Output
           ("Validate_Characters (boolean) " & Get_Name (Validator));
      end if;

      if Ch = "" then
         Validation_Error
           (Reader, "#Invalid value for boolean type: """ & Ch & """");
      end if;

      Check_Facet (Get_Facets (Validator, Reader).all, Reader, Ch, Mask);
      Val := Value (Reader, Ch);
   end Validate_Characters;

   ---------------
   -- Add_Facet --
   ---------------

   procedure Add_Facet
     (Validator   : access Boolean_Validator_Record;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence)
   is
      Applies : Boolean;
   begin
      Add_Facet
        (Get_Facets (Validator, Reader).all, Reader,
         Facet_Name, Facet_Value, Applies);
      if not Applies then
         Validation_Error (Reader, "#Invalid facet: " & Facet_Name);
      end if;
   end Add_Facet;

   -----------------------
   -- String_Get_Length --
   -----------------------

   function String_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural is
   begin
      return Sax.Encodings.Encoding.Length (Value);
   end String_Get_Length;

   ----------------------------
   -- String_List_Get_Length --
   ----------------------------

   function String_List_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural
   is
      Length : Natural := 0;
      C      : Unicode_Char;
      Index  : Natural := Value'First;
   begin
      if Value = "" then
         return 0;
      end if;

      while Index <= Value'Last loop
         Encoding.Read (Value, Index, C);
         while C = Unicode.Names.Basic_Latin.Space loop
            Length := Length + 1;
            Encoding.Read (Value, Index, C);
         end loop;
      end loop;

      return Length + 1;
   end String_List_Get_Length;

   --------------------------
   -- HexBinary_Get_Length --
   --------------------------

   function HexBinary_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural is
   begin
      return Sax.Encodings.Encoding.Length (Value) / 2;
   end HexBinary_Get_Length;

   ---------------------------
   -- Is_Valid_Base64Binary --
   ---------------------------

   function Is_Valid_Base64Binary
     (Value : Unicode.CES.Byte_Sequence) return Boolean
   is
      Index         : Integer := Value'First;
      C             : Unicode_Char;
      Prev_Is_Space : Boolean := False;

      Group         : Natural := 1;
      --  Characters are always by groups of 4, this variable indicates the
      --  index of the current char in the group

      type Char_Categorie is (Char_04, Char_16, Char_64, Char_Equal);
      Chars  : array (1 .. 4) of Char_Categorie;
      --  The various categories that characters can belong two. In the Base64
      --  encoding, we always have groups of 4 characters.

   begin
      while Index <= Value'Last loop
         Sax.Encodings.Encoding.Read (Value, Index, C);

         if C = 16#20# or C = 16#A# then
            if Prev_Is_Space then
               return False;  --  Can never have two spaces in a row
            end if;
            Prev_Is_Space := True;

         elsif C in B04'Range and then B04 (C) then
            Prev_Is_Space := False;
            Chars (Group) := Char_04;
            Group := Group + 1;

         elsif C in B16'Range and then B16 (C) then
            Prev_Is_Space := False;
            Chars (Group) := Char_16;
            Group := Group + 1;

         elsif C in B64'Range and then B64 (C) then
            Prev_Is_Space := False;
            Chars (Group) := Char_64;
            Group := Group + 1;

         elsif C = Character'Pos ('=') then
            Prev_Is_Space := False;
            if Group = 3
              and then Chars (1) <= Char_64
              and then Chars (2) = Char_04
            then
               Chars (Group) := Char_Equal;
               Group := Group + 1;

            elsif Group = 4
              and then Chars (1) <= Char_64
              and then Chars (2) <= Char_64
              and then Chars (3) <= Char_16
            then
               Group := 1;
               exit;  --  Must end now

            elsif Group = 4
              and then Chars (1) <= Char_64
              and then Chars (2) <= Char_04
              and then Chars (3) <= Char_Equal
            then
               Group := 1;
               exit;  --  Must end now

            else
               return False;
            end if;

         else
            return False;
         end if;

         if Group > 4 then
            Group := 1;
         end if;
      end loop;

      --  Cannot finish with a space
      if Prev_Is_Space or Group /= 1 or Index <= Value'Last then
         return False;
      end if;

      return True;
   end Is_Valid_Base64Binary;

   -----------------------------
   -- Base64Binary_Get_Length --
   -----------------------------

   function Base64Binary_Get_Length
     (Value : Unicode.CES.Byte_Sequence) return Natural
   is
      Length : Natural := 0;
      C : Unicode_Char;
      Index : Positive := Value'First;
   begin
      while Index <= Value'Last loop
         Sax.Encodings.Encoding.Read (Value, Index, C);
         if C /= 16#20#
           and then C /= 16#A#
           and then C /= Character'Pos ('=')
         then
            Length := Length + 1;
         end if;
      end loop;
      return Length * 3 / 4;
   end Base64Binary_Get_Length;

   -----------------
   -- Check_Facet --
   -----------------

   procedure Check_Facet
     (Facets      : in out Float_Facets_Description;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Value : Unicode.CES.Byte_Sequence;
      Mask        : in out Facets_Mask)
   is
      use Float_Facets_Package;
   begin
      if Facet_Value = "NaN" then
         if (Facets.Mask (Facet_Max_Inclusive) and Mask (Facet_Max_Inclusive))
           or (Facets.Mask (Facet_Max_Exclusive)
               and Mask (Facet_Max_Exclusive))
         then
            Validation_Error
              (Reader,
               "#NaN is greater than all numbers, "
               & "and too big in this context");
         end if;
         Mask (Facet_Max_Inclusive) := False;
         Mask (Facet_Max_Exclusive) := False;

      elsif Facet_Value = "INF" then
         if (Facets.Mask (Facet_Max_Inclusive)
             and Mask (Facet_Max_Inclusive))
           or (Facets.Mask (Facet_Max_Exclusive)
               and Mask (Facet_Max_Exclusive))
         then
            Validation_Error
              (Reader,
               "#INF is greater than maxInclusive and maxExclusive");
         end if;
         Mask (Facet_Max_Inclusive) := False;
         Mask (Facet_Max_Exclusive) := False;

      elsif Facet_Value = "-INF" then
         if (Facets.Mask (Facet_Min_Inclusive)
             and Mask (Facet_Min_Inclusive))
           or (Facets.Mask (Facet_Min_Exclusive)
               and Mask (Facet_Min_Exclusive))
         then
            Validation_Error
              (Reader, "#-INF is smaller than minInclusive and minExclusive");
         end if;
         Mask (Facet_Min_Inclusive) := False;
         Mask (Facet_Min_Exclusive) := False;
      end if;

      Check_Facet
        (Float_Facets_Package.Range_Facets_Description (Facets),
         Reader, Facet_Value, Mask);
   end Check_Facet;

   -------------------------------
   -- Register_Predefined_Types --
   -------------------------------

   procedure Register_Predefined_Types
     (G, XML_G : XML_Grammar_NS;
      Reader   : access Abstract_Validation_Reader'Class)
   is
      use Integer_Validators, String_Validators, String_List_Validators;
      use HexBinary_Validators, Base64Binary_Validators, Decimal_Validators;
      use String_Facets, String_List_Facets,
          HexBinary_Facets, Base64Binary_Facets;
      Tmp     : XML_Validator;
      Str     : String_Validators.Validator;
      StrList : String_List_Validators.Validator;
      Hex     : HexBinary_Validators.Validator;
      Base64  : Base64Binary_Validators.Validator;
      Int     : Integer_Validators.Validator;
      Dec     : Decimal_Validators.Validator;
      QN      : QName_Validators.Validator;
      Created : XML_Type;
   begin
      Tmp := new Boolean_Validator_Record;
      Create_Global_Type (G, Reader, "boolean", Tmp);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Create_Global_Type (G, Reader, "string", Str);

      QN  := new QName_Validator;
      Create_Global_Type (G, Reader, "QName", QN);

      QN  := new QName_Validator;
      Create_Global_Type (G, Reader, "NOTATION", QN);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "replace");
      Create_Global_Type (G, Reader, "normalizedString", Str);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "collapse");
      Create_Global_Type (G, Reader, "token", Str);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_Language_Name'Access);
      Created := Create_Global_Type (G, Reader, "language", Str);
      Create_Global_Attribute (XML_G, Reader, "lang", Created);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "collapse");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_Nmtoken'Access);
      Create_Global_Type (G, Reader, "NMTOKEN", Str);

      StrList := new String_List_Validators.Validator_Record;
      Add_Facet (StrList, Reader, "whiteSpace", "collapse");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (StrList, Reader).all),
         Is_Valid_Nmtokens'Access);
      Create_Global_Type (G, Reader, "NMTOKENS", StrList);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_Name'Access);
      Create_Global_Type (G, Reader, "Name", Str);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_NCname'Access);
      Create_Global_Type (G, Reader, "NCName", Str);

      Str := new ID_Validator;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_NCname'Access);
      Create_Global_Type (G, Reader, "ID", Str);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_NCname'Access);
      Create_Global_Type (G, Reader, "IDREF", Str);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_NCnames'Access);
      Create_Global_Type (G, Reader, "IDREFS", Str);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_NCname'Access);
      Create_Global_Type (G, Reader, "ENTITY", Str);

      Str := new String_Validators.Validator_Record;
      Add_Facet (Str, Reader, "whiteSpace", "preserve");
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_NCnames'Access);
      Create_Global_Type (G, Reader, "ENTITIES", Str);

      Str := new String_Validators.Validator_Record;
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Str, Reader).all),
         Is_Valid_URI'Access);
      Create_Global_Type (G, Reader, "anyURI", Str);

      Hex := new HexBinary_Validator;
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Hex, Reader).all),
         Is_Valid_HexBinary'Access);
      Create_Global_Type (G, Reader, "hexBinary", Hex);

      Base64 := new Base64Binary_Validators.Validator_Record;
      Set_Implicit_Enumeration
        (Common_Facets_Description (Get_Facets (Base64, Reader).all),
         Is_Valid_Base64Binary'Access);
      Create_Global_Type (G, Reader, "base64Binary", Base64);

      Dec := new Decimal_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "decimal", Dec);

      Dec := new Decimal_Validators.Validator_Record;
      Add_Facet (Dec, Reader, "fractionDigits", "0");
      Add_Facet (Dec, Reader, "maxInclusive", "+18446744073709551615");
      Add_Facet (Dec, Reader, "minInclusive", "0");
      Create_Global_Type (G, Reader, "unsignedLong", Dec);

      Dec := new Decimal_Validators.Validator_Record;
      Add_Facet (Dec, Reader, "fractionDigits", "0");
      Create_Global_Type (G, Reader, "integer", Dec);

      Dec := new Decimal_Validators.Validator_Record;
      Add_Facet (Dec, Reader, "minInclusive", "0");
      Create_Global_Type (G, Reader, "nonNegativeInteger", Dec);

      Dec := new Decimal_Validators.Validator_Record;
      Add_Facet (Dec, Reader, "minInclusive", "1");
      Create_Global_Type (G, Reader, "positiveInteger", Dec);

      Dec := new Decimal_Validators.Validator_Record;
      Add_Facet (Dec, Reader, "maxInclusive", "0");
      Create_Global_Type (G, Reader, "nonPositiveInteger", Dec);

      Dec := new Decimal_Validators.Validator_Record;
      Add_Facet (Dec, Reader, "maxInclusive", "-1");
      Create_Global_Type (G, Reader, "negativeInteger", Dec);

      Int := new Integer_Validators.Validator_Record;
      Add_Facet (Int, Reader, "maxInclusive", "+9223372036854775807");
      Add_Facet (Int, Reader, "minInclusive", "-9223372036854775808");
      Create_Global_Type (G, Reader, "long", Int);

      Int := new Integer_Validators.Validator_Record;
      Add_Facet (Int, Reader, "maxInclusive", "+2147483647");
      Add_Facet (Int, Reader, "minInclusive", "-2147483648");
      Create_Global_Type (G, Reader, "int", Int);

      Int := new Integer_Validators.Validator_Record;
      Add_Facet (Int, Reader, "maxInclusive", "+32767");
      Add_Facet (Int, Reader, "minInclusive", "-32768");
      Create_Global_Type (G, Reader, "short", Int);

      Int := new Integer_Validators.Validator_Record;
      Add_Facet (Int, Reader, "maxInclusive", "+127");
      Add_Facet (Int, Reader, "minInclusive", "-128");
      Create_Global_Type (G, Reader, "byte", Int);

      Int := new Integer_Validators.Validator_Record;
      Add_Facet (Int, Reader, "maxInclusive", "+4294967295");
      Add_Facet (Int, Reader, "minInclusive", "0");
      Create_Global_Type (G, Reader, "unsignedInt", Int);

      Int := new Integer_Validators.Validator_Record;
      Add_Facet (Int, Reader, "maxInclusive", "+65535");
      Add_Facet (Int, Reader, "minInclusive", "0");
      Create_Global_Type (G, Reader, "unsignedShort", Int);

      Int := new Integer_Validators.Validator_Record;
      Add_Facet (Int, Reader, "maxInclusive", "+255");
      Add_Facet (Int, Reader, "minInclusive", "0");
      Create_Global_Type (G, Reader, "unsignedByte", Int);

      Tmp := new Float_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "float", Tmp);

      Tmp := new Float_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "double", Tmp);

      Tmp := new Time_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "time", Tmp);

      Tmp := new Date_Time_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "dateTime", Tmp);

      Tmp := new GDay_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "gDay", Tmp);

      Tmp := new GMonth_Day_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "gMonthDay", Tmp);

      Tmp := new GMonth_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "gMonth", Tmp);

      Tmp := new GYear_Month_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "gYearMonth", Tmp);

      Tmp := new GYear_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "gYear", Tmp);

      Tmp := new Date_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "date", Tmp);

      Tmp := new Duration_Validators.Validator_Record;
      Create_Global_Type (G, Reader, "duration", Tmp);

      Tmp := Restriction_Of (G, Reader, Lookup (G, Reader, "anySimpleType"));
      Add_Facet (Tmp, Reader, "whiteSpace", "collapse");
      Create_Global_Type (G, Reader, "uriReference", Tmp);
   end Register_Predefined_Types;

   ----------------------------
   -- Validate_Start_Element --
   ----------------------------

   procedure Validate_Start_Element
     (Validator         : access Any_Simple_XML_Validator_Record;
      Reader            : access Abstract_Validation_Reader'Class;
      Local_Name        : Unicode.CES.Byte_Sequence;
      NS                : XML_Grammar_NS;
      Data              : Validator_Data;
      Element_Validator : out XML_Element)
   is
      pragma Unreferenced (Validator, Data, NS);
   begin
      Validation_Error
        (Reader,
         "#Must be a simple type, no <" & Local_Name & "> child allowed");
      Element_Validator := No_Element;
   end Validate_Start_Element;

   --------------------------
   -- Validate_End_Element --
   --------------------------

   procedure Validate_End_Element
     (Validator      : access Any_Simple_XML_Validator_Record;
      Reader         : access Abstract_Validation_Reader'Class;
      Local_Name     : Unicode.CES.Byte_Sequence;
      Data           : Validator_Data)
   is
      pragma Unreferenced (Validator, Local_Name, Data, Reader);
   begin
      null;
   end Validate_End_Element;

   ---------------
   -- Add_Union --
   ---------------

   procedure Add_Union
     (Validator : access XML_Union_Record;
      Reader    : access Abstract_Validation_Reader'Class;
      Part      : XML_Type) is
   begin
      Append
        (Validator.Unions, Reader, XML_Particle'
           (Typ        => Particle_XML_Type,
            Type_Descr => Part,
            Next       => null,
            Min_Occurs => 1,
            Max_Occurs => 1));
   end Add_Union;

   ----------------
   -- Get_Facets --
   ----------------

   function Get_Facets
     (Validator : access XML_Union_Record;
      Reader    : access Abstract_Validation_Reader'Class)
      return Facets_Description is
   begin
      if Validator.Facets = null then
         Validator.Facets := new Common_Facets_Description;
         Add_Facet (Validator, Reader, "whiteSpace", "collapse");
      end if;

      return Validator.Facets;
   end Get_Facets;

   -----------
   -- Equal --
   -----------

   function Equal
     (Validator      : access XML_Union_Record;
      Reader         : access Abstract_Validation_Reader'Class;
      Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean
   is
      Iter : Particle_Iterator;
   begin
      if Validator.Unions /= null then
         Iter := Start (Validator.Unions);
         while Get (Iter) /= null loop
            begin
               if Equal
                 (Get_Validator (Get (Iter).Type_Descr),
                  Reader, Value1, Value2)
               then
                  Free (Iter);
                  return True;
               end if;
            exception
               when others =>
                  null;
            end;

            Next (Iter);
         end loop;

         Free (Iter);
      end if;

      return False;
   end Equal;

   -------------------------
   -- Validate_Characters --
   -------------------------

   procedure Validate_Characters
     (Union         : access XML_Union_Record;
      Reader        : access Abstract_Validation_Reader'Class;
      Ch            : Unicode.CES.Byte_Sequence;
      Empty_Element : Boolean;
      Mask          : in out Facets_Mask)
   is
      Iter : Particle_Iterator;
      Valid : XML_Validator;
   begin
      if Debug then
         Debug_Output ("Validate_Characters (union) " & Get_Name (Union));
      end if;

      if Union.Unions = null then
         if Empty_Element then
            return;
         else
            Validation_Error (Reader, "#No content allowed for this union");
         end if;
      end if;

      Iter := Start (Union.Unions);
      while Get (Iter) /= null loop
         begin
            Valid := Get_Validator (Get (Iter).Type_Descr);
            if Valid /= null then
               Validate_Characters (Valid, Reader, Ch, Empty_Element, Mask);
            end if;

            --  No error ? => Everything is fine
            Free (Iter);
            return;

         exception
            when XML_Validation_Error =>
               null;
         end;

         Next (Iter);
      end loop;

      Free (Iter);
      Validation_Error (Reader, "#Invalid value """ & Ch & """");
   end Validate_Characters;

   ------------------------
   -- Check_Content_Type --
   ------------------------

   procedure Check_Content_Type
     (Validator        : access Any_Simple_XML_Validator_Record;
      Reader           : access Abstract_Validation_Reader'Class;
      Should_Be_Simple : Boolean)
   is
      pragma Unreferenced (Validator);
   begin
      if not Should_Be_Simple then
         Validation_Error
           (Reader, "#Expecting simple type, got complex type");
      end if;
   end Check_Content_Type;

   -------------------------
   -- Validate_Characters --
   -------------------------

   procedure Validate_Characters
     (Validator      : access Any_Simple_XML_Validator_Record;
      Reader         : access Abstract_Validation_Reader'Class;
      Ch             : Unicode.CES.Byte_Sequence;
      Empty_Element  : Boolean;
      Mask           : in out Facets_Mask)
   is
      pragma Unreferenced (Ch, Empty_Element, Mask, Reader);
   begin
      if Debug then
         Debug_Output ("Validate_Character (anySimpleType) "
                       & Get_Name (Validator));
      end if;
   end Validate_Characters;

   ----------
   -- Free --
   ----------

   procedure Free (Union : in out XML_Union_Record) is
   begin
      Free (Union.Unions);
      Free (Any_Simple_XML_Validator_Record (Union));
   end Free;

   ----------------
   -- Get_Facets --
   ----------------

   function Get_Facets
     (Validator : access Any_Simple_XML_Validator_Record;
      Reader    : access Abstract_Validation_Reader'Class)
      return Facets_Description
   is
      pragma Unreferenced (Reader);
   begin
      if Validator.Facets = null then
         Validator.Facets := new Common_Facets_Description;
      end if;
      return Validator.Facets;
   end Get_Facets;

   ---------------
   -- Add_Facet --
   ---------------

   procedure Add_Facet
     (Validator   : access Any_Simple_XML_Validator_Record;
      Reader      : access Abstract_Validation_Reader'Class;
      Facet_Name  : Unicode.CES.Byte_Sequence;
      Facet_Value : Unicode.CES.Byte_Sequence)
   is
      Applied : Boolean;
   begin
      Add_Facet (Get_Facets (Validator, Reader).all, Reader,
                 Facet_Name, Facet_Value, Applied);
   end Add_Facet;

   ----------
   -- Free --
   ----------

   procedure Free (Validator : in out Any_Simple_XML_Validator_Record) is
   begin
      Free (Validator.Facets);
      Free (XML_Validator_Record (Validator));
   end Free;

   ---------------------------------
   -- Check_Replacement_For_Union --
   ---------------------------------

   procedure Check_Replacement_For_Union
     (Validator         : access XML_Validator_Record'Class;
      Union             : XML_Union_Record;
      Element           : XML_Element;
      Valid             : out Boolean;
      Had_Restriction   : in out Boolean;
      Had_Extension     : in out Boolean)
   is
      Iter : Particle_Iterator;
      V    : XML_Validator;
   begin
      Valid := False;

      if Union.Unions /= null then
         Iter := Start (Union.Unions);
         while Get (Iter) /= null loop
            V := Get_Validator (Get (Iter).Type_Descr);
            if V /= null then
               Check_Replacement
                 (Validator, Element, Get (Iter).Type_Descr,
                  Valid, Had_Restriction, Had_Extension);
               if Valid then
                  Free (Iter);
                  return;
               end if;
            end if;
            Next (Iter);
         end loop;

         Free (Iter);
      end if;
   end Check_Replacement_For_Union;

   -----------
   -- Equal --
   -----------

   function Equal
     (Validator      : access Any_Simple_XML_Validator_Record;
      Reader         : access Abstract_Validation_Reader'Class;
      Value1, Value2 : Unicode.CES.Byte_Sequence) return Boolean is
   begin
      return Equal
        (Common_Facets_Description'Class
           (Get_Facets (Validator, Reader).all), Reader, Value1, Value2);
   end Equal;

end Schema.Validators.Simple_Types;
