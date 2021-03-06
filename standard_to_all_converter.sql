CREATE OR REPLACE 
FUNCTION inventory.standard_to_all_converter(
  quantity            numeric,
  from_unit           text,
  from_bulk_density   numeric,
  schemaname          text default '',
  tablename           text default '',
  entity_id           integer default -1, -- requires every table using unit_converion to have an integer id
  all_mode            text default 'all'
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
custom_unit_key record;
from_definition jsonb;
local_result jsonb;
result_standard jsonb := '{}'::jsonb;
result_custom jsonb := '{}'::jsonb;
result jsonb := '{"error": null, "result": null}'::jsonb;
converted_value numeric;

BEGIN  

  IF all_mode = 'standard' OR all_mode = 'all' THEN

    from_definition := definitions -> from_unit;

    FOR unit_key IN SELECT key, value FROM jsonb_each(definitions) LOOP
      -- unit_key is definition from definitions.
      IF unit_key.value -> 'bulkDensity' THEN
        -- to is volume
        IF from_definition -> 'bulkDensity' THEN
          -- from is volume too
          converted_value := quantity * (from_definition->>'factor')::numeric / (unit_key.value->>'factor')::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            unit_key.key,
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        ELSE
          -- from is mass
          converted_value := quantity * (from_definition->>'factor')::numeric / (unit_key.value->>'factor')::numeric / (unit_key.value->>'bulkDensity')::numeric;

          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            unit_key.key,
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
          converted_value := quantity *  (from_definition->>'factor')::numeric / (unit_key.value->>'factor')::numeric * (from_unit_bulk_density)::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            unit_key.key,
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        ELSE
          -- from is mass too
          converted_value := quantity * (from_definition->>'factor')::numeric / (unit_key.value->>'factor')::numeric;
            
          local_result := jsonb_build_object(
            'fromUnitName',
            from_unit,
            'toUnitName',
            unit_key.key,
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        END IF;
      END IF;
      result_standard := result_standard || jsonb_build_object(unit_key.key, local_result);
    END LOOP;

  END IF;

  IF all_mode = 'custom' OR all_mode = 'all' THEN

    FOR custom_unit_key IN
      EXECUTE format(
        $$SELECT 
          "inputUnitName" input_unit, 
          "outputUnitName" output_unit, 
          "conversionFactor" conversion_factor, 
          "unitConversionId" unit_conversion_id
        FROM %I.%I
        INNER JOIN master."unitConversion"
        ON "unitConversionId" = "unitConversion".id
        WHERE "entityId" = (%s)::integer;$$,
        schemaname,
        tablename,
        entity_id
      )
      LOOP

        SELECT data FROM inventory.standard_to_custom_unit_converter(
          quantity,
          from_unit, 
          from_bulk_density,
          custom_unit_key.input_unit,
          (1)::numeric,
          custom_unit_key.unit_conversion_id
        ) INTO local_result;

        result_custom := result_custom || jsonb_build_object(custom_unit_key.input_unit, local_result);

      END LOOP;

  END IF;

  result := jsonb_build_object(
    'result',
    jsonb_build_object('standard', result_standard, 'custom', result_custom),
    'error',
    'null'::jsonb
  );

RETURN QUERY
SELECT
  1 AS id,
  result as data;
END;

$function$
