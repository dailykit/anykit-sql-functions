/* 
  Hasura computed field that return possible unit_conversion for a table 
  required columns in table: (unit text, quantity numeric) 
  optional columns: (bulkDensity numeric)_id 
*/

-- for supplierItem Table (unit text, unitSize integer)
CREATE OR REPLACE FUNCTION inventory.unit_conversions_supplier_item(
  item                    inventory."supplierItem", -- passed by hasura
  from_unit               text,                     -- if '', take value from `item`
  from_unit_bulk_density  numeric,                  -- -1 to take value from `item`
  quantity                numeric,                  -- -1 to take value from `item`
  to_unit                 text,                     -- if '', convert to all possible units
  to_unit_bulk_density    numeric                   -- -1 to take value from `item`
) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$
DECLARE

  local_quantity                   numeric;
  local_from_unit                  text; 
  local_from_unit_bulk_density     numeric; 
  local_to_unit_bulk_density       numeric;

  known_units                      text[] := '{kg, g, mg, oz, l, ml}';
  result                           jsonb;
  custom_to_unit_conversion_id     integer;
  custom_from_unit_conversion_id   integer;

BEGIN

  /* setup */

  -- resolve quantity
  IF quantity IS NULL 
    OR quantity = -1 THEN
    
    local_quantity := item."unitSize"::numeric;
  ELSE
    local_quantity := quantity;
  END IF;

  -- resolve from_unit
  IF from_unit IS NULL 
    OR from_unit = ''
    THEN
    local_from_unit := item.unit;
  ELSE
    local_from_unit := from_unit;
  END IF;

  -- resolve from_unit_bulk_density
  IF from_unit_bulk_density IS NULL 
    OR from_unit_bulk_density = -1 THEN

    local_from_unit_bulk_density := item."bulkDensity";
  ELSE
    local_from_unit_bulk_density := from_unit_bulk_density;
  END IF;

  -- resolve to_unit_bulk_density
  IF to_unit_bulk_density IS NULL 
    OR to_unit_bulk_density = -1 THEN

    local_to_unit_bulk_density := item."bulkDensity";
  ELSE
    local_to_unit_bulk_density := to_unit_bulk_density;
  END IF;

  IF to_unit <> ALL(known_units) AND to_unit != '' THEN
    EXECUTE format(
      $$SELECT 
        "unitConversionId" unit_conversion_id
      FROM %I.%I
      INNER JOIN master."unitConversion"
      ON "unitConversionId" = "unitConversion".id
      WHERE "entityId" = (%s)::integer
      AND "inputUnitName" = '%s';$$,
      'inventory', -- schema name
      'supplierItem_unitConversion', -- tablename
      item.id,
      to_unit
    ) INTO custom_to_unit_conversion_id;
  END IF;

  IF local_from_unit <> ALL(known_units) THEN
    EXECUTE format(
      $$SELECT 
        "unitConversionId" unit_conversion_id
      FROM %I.%I
      INNER JOIN master."unitConversion"
      ON "unitConversionId" = "unitConversion".id
      WHERE "entityId" = (%s)::integer
      AND "inputUnitName" = '%s';$$,
      'inventory', -- schema name
      'supplierItem_unitConversion', -- tablename
      item.id,
      local_from_unit
    ) INTO custom_from_unit_conversion_id;
  END IF;

  /* end setup */

  IF local_from_unit = ANY(known_units) THEN -- local_from_unit is standard
    IF to_unit = ANY(known_units)
      OR to_unit = ''
      OR to_unit IS NULL THEN -- to_unit is also standard

        SELECT data FROM inventory.standard_to_standard_unit_converter(
          local_quantity, 
          local_from_unit, 
          local_from_unit_bulk_density,
          to_unit,
          local_to_unit_bulk_density,
          'inventory', -- schema name
          'supplierItem_unitConversion', -- tablename
          item.id,
          'all'
        ) INTO result;

    ELSE -- to_unit is custom and not ''

      -- convert from standard to custom
      SELECT data FROM inventory.standard_to_custom_unit_converter(
        local_quantity, 
        local_from_unit, 
        local_from_unit_bulk_density,
        to_unit,
        local_to_unit_bulk_density,
        custom_to_unit_conversion_id     
      ) INTO result;

    END IF;

  ELSE -- local_from_unit is custom
    
    IF to_unit = ANY(known_units) 
      OR to_unit = ''
      OR to_unit IS NULL THEN -- to_unit is standard

      SELECT data FROM inventory.custom_to_standard_unit_converter(
        local_quantity, 
        local_from_unit, 
        local_from_unit_bulk_density,
        to_unit,
        local_to_unit_bulk_density,
        custom_from_unit_conversion_id,
        'inventory', -- schema name
        'supplierItem_unitConversion', -- tablename
        item.id
      ) INTO result;

    ELSE -- to_unit is also custom and not ''

      SELECT data FROM inventory.custom_to_custom_unit_converter(
        local_quantity, 
        local_from_unit, 
        local_from_unit_bulk_density, 
        to_unit,
        local_to_unit_bulk_density,
        custom_from_unit_conversion_id,
        custom_to_unit_conversion_id     
      ) INTO result;

    END IF;
  END IF;

  RETURN QUERY
  SELECT
    1 as id,
    result as data;

END;
$function$
