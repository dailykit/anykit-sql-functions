/*

  This function is called only when:

    1. from_unit is not null and IN standard_units_definition.
    2. to_unit is '' or IN standard_units_definition.

*/
CREATE OR REPLACE 
FUNCTION inventory.standard_to_standard_unit_converter(
  quantity numeric, 
  from_unit text, 
  from_bulk_density numeric, 
  to_unit text,
  to_unit_bulk_density numeric,
  schemaname text,
  tablename text,
  entity_id integer,
  all_mode text default 'all'
) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$ 
DECLARE 
-- all these are standard definitions. The base for mass should be in g (grams).
-- the base for volumes should be in ml (mililitres)
-- the bulkDensity should only be available in volumes.
-- the value of bulkDensity should be between 0-1.
-- this value of bulkDensity tells the equivalent mass of this volume in base of volume (ml) to the base of mass (g).
definitions jsonb := $${"kg":{"name":{"abbr":"kg","singular":"Kilogram","plural":"Kilograms"},"base":"g","factor":1000},
                        "g":{"name":{"abbr":"g","singular":"Gram","plural":"Grams"},"base":"g","factor":1},
                        "mg":{"name":{"abbr":"mg","singular":"Miligram","plural":"MiliGrams"},"base":"g","factor":0.001},
                        "oz":{"name":{"abbr":"oz","singular":"Ounce","plural":"Ounces"},"base":"g","factor":28.3495},
                        "l":{"name":{"abbr":"l","singular":"Litre","plural":"Litres"},"base":"ml","factor":1000,"bulkDensity":1},
                        "ml":{"name":{"abbr":"ml","singular":"Millilitre","plural":"Millilitres"},"base":"ml","factor":1,"bulkDensity":1}
                        }$$;
unit_key record;
from_definition jsonb;
to_definition jsonb;
local_result jsonb;
result_standard jsonb := '{}'::jsonb;
result jsonb := '{"error": null, "result": null}'::jsonb;
converted_value numeric;

BEGIN  

  -- 1. get the from definition of this unit;
  from_definition := definitions -> from_unit;

  -- gql forces the value of uni_to, passing '' should work.
  IF to_unit IS NOT NULL OR to_unit != '' THEN
      to_definition := definitions -> to_unit;

      IF to_definition -> 'bulkDensity' THEN
        -- to is volume
        IF from_definition -> 'bulkDensity' THEN
          -- from is volume too
          -- ignore bulkDensity as they should be same in volume to volume of same entity.
          converted_value := quantity * (from_definition->>'factor')::numeric / (to_definition->>'factor')::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            to_definition->'name'->>'abbr',
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        ELSE
          -- from is mass
          converted_value := quantity * (from_definition->>'factor')::numeric / (to_definition->>'factor')::numeric / (to_unit_bulk_density)::numeric;

          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            to_definition->'name'->>'abbr',
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        END IF;
      ELSE
        -- to is mass
        IF from_definition -> 'bulkDensity' THEN
          -- from is volume 
          converted_value := quantity * (from_definition->>'factor')::numeric / (to_definition->>'factor')::numeric * (from_bulk_density)::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            to_definition->'name'->>'abbr',
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        ELSE
          -- from is mass too
          converted_value := quantity * (from_definition->>'factor')::numeric / (to_definition->>'factor')::numeric;
            
          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            to_definition->'name'->>'abbr',
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        END IF;
      END IF;
      
    result_standard := result_standard || jsonb_build_object(to_definition->'name'->>'abbr', local_result);

    result := jsonb_build_object(
      'result',
      jsonb_build_object('standard', result_standard),
      'error',
      'null'::jsonb
    );

  ELSE -- to_unit is '', convert to all (standard to custom)

    SELECT data from inventory.standard_to_all_converter(
      quantity,
      from_unit, 
      from_bulk_density,
      schemaname,
      tablename,
      entity_id,
      all_mode
    ) INTO result;

  END IF;
RETURN QUERY
SELECT
  1 AS id,
  result as data;
END;

$function$

