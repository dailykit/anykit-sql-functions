/* 
  Hasura computed field that return possible unit_conversion for a table 
  required columns in table: (unit text, quantity numeric) 
  optional columns: (bulkDensity numeric)_id 
*/

-- for supplierItem Table (unit text, unitSize integer)
CREATE OR REPLACE FUNCTION inventory.unit_conversions_supplier_item(item inventory."supplierItem", to_unit text default null, to_unit_id integer default null) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$
DECLARE

known_units text[] := '{kg, g, mg, oz, l, ml}';
result jsonb;

BEGIN

  IF item.unit = ANY(known_units) THEN -- unit is standard
    IF to_unit = ANY(known_units) 
      OR to_unit = '' 
      OR to_unit IS NULL
      THEN -- unit and to_unit is standard
      -- supplierItem table does not have the bulkDensity field.
      -- default value for bulkDensity should be -1.
      SELECT data FROM inventory."unitVariationFunc"(item."unitSize"::numeric, item.unit, (-1)::numeric, to_unit, item."unitConversionId") 
        INTO result;
    ELSE -- unit is standard but to_unit is custom
      -- convert from standard to custom
      SELECT data FROM inventory."standardToCustomUnitConverter"(item."unitSize"::numeric, item.unit, -1, to_unit_id) 
        INTO result;
    END IF;
  ELSE -- unit is custom
    -- TODO: when unit is custom, args used should be item."unitConversionId"
    IF to_unit = ANY(known_units) 
      OR to_unit = ''
      OR to_unit IS NULL
      THEN -- unit is custom but unit_to is standard
      -- supplierItem table does not have the bulkDensity field.
      -- default value for bulkDensity should be -1.
      SELECT data FROM inventory."unitVariationFunc"(item."unitSize"::numeric, item.unit, (-1)::numeric, to_unit, item."unitConversionId") 
        INTO result;
    ELSE -- unit and to_unit are custom
      -- TODO: change args to get item."unitConversionId" and to_unit_id
      SELECT data FROM inventory."customToCustomUnitConverter"(item."unitSize"::numeric, item."unitConversionId", (-1)::numeric, to_unit_id) 
        INTO result;
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    1 as id,
    result as data;

END;
$function$
