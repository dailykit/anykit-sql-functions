/* 
  Hasura computed field that return possible unit_conversion for a table 
  required columns in table: (unit text, quantity numeric) 
  optional columns: (bulkDensity numeric)_id 
*/

/*
  @param input jsonb 
  {
      "givenQuantity" : "100", if not given, default is 1
      "givenUnit*" : "kg",
      "returnUnits" : [crate, jar],
      "appliedUnitConversions" : [3,4,5,6,7,8],
      "tablename": "",
      "schemaname": "",
  }
*/
-- example argument for @param input
/* {"givenQuantity" : 100, "bulkDensity": 1, "givenUnit" : "kg", "returnUnits" : ["crate", "oz", "kg", "g", "bag"], "customUnitConversionIds" : [2,6]} */

-- for supplierItem Table (unit text, unitSize integer)
CREATE OR REPLACE FUNCTION inventory.unit_conversions_supplier_item(
  item                    inventory."supplierItem", -- passed by hasura
  input                   jsonb
) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$
DECLARE

  local_quantity    numeric;
  local_return_units text[];
  local_custom_unit_ids int[];
  bulk_density      numeric;

  result            jsonb := '{}';
  rule              record;

BEGIN

  /* setup */

  -- resolve quantity
  IF input -> 'givenQuantity' IS NULL THEN
    -- take quantity from item record
    CASE WHEN item."unitSize" IS NULL THEN
      local_quantity := 1;
    ELSE 
      local_quantity := item."unitSize"::numeric;
    END CASE;
  ELSE
    -- take quantity from input jsonb arg
    local_quantity := (input ->> 'givenQuantity')::numeric;
  END IF;

  -- resolve bulk_density
  IF input -> 'bulkDensity' IS NULL THEN
    bulk_density := item."bulkDensity";
  ELSE
    bulk_density := (input -> 'bulkDensity')::numeric;
  END IF;


  local_return_units := json_to_array((input->'returnUnits')::json);
  local_custom_unit_ids := (json_to_array((input->'customUnitConversionIds')::json))::int[];


  /* end setup */

  result := inventory.convert_units(local_quantity, input->>'givenUnit', local_return_units, local_custom_unit_ids);

  RETURN QUERY
  SELECT
    1 as id,
    result as data;

END;
$function$
