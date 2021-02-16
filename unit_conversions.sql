/* 
  Hasura computed field that return possible unit_conversion for a table 
  required columns in table: (unit text, quantity numeric) 
  optional columns: (bulkDensity numeric) 
*/

-- for supplierItem Table (unit text, unitSize integer)
CREATE OR REPLACE FUNCTION inventory.unit_conversions_supplier_item(item inventory."supplierItem", to_unit text default null) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$
DECLARE

known_units text[] := '{kg, g, mg, oz, l, ml}';
result jsonb;

BEGIN

  IF to_unit = ANY(known_units) THEN
    -- supplierItem table does not have the bulkDensity field.
    -- default value for bulkDensity should be -1.
    SELECT data FROM inventory."unitVariationFunc"('supplierItem', item."unitSize"::numeric, item.unit, -1, to_unit) 
      INTO result;
  ELSE
    -- convert from standard to custom
    SELECT data FROM inventory."standardToCustomUnitConverter"(item."unitSize"::numeric, item.unit, -1, to_unit) 
      INTO result;
  END IF;

  RETURN QUERY
  SELECT
    1 as id,
    result as data;

END;
$function$
