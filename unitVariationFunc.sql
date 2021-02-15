/* -> create `unitVariationFunc` sql function */
/*     @params: tableName text, quantity numeric, unit text, bulkDensity numeric default 1, unitTo text default 'null' */
/*     @returns: json{custom: {[unitName]: value}, standard: {[unitName]: value}} */

-- TODO: ACK fromBulkDensity (bulkDensity param)
-- TODO: ACK unitTo param
-- TODO: for volumes, add usedBulkDensity in response object

CREATE OR REPLACE FUNCTION inventory."unitVariationFunc"(tableName text, quantity numeric, unit text, bulkDensity numeric default 1, unitTo text default null) 
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
known_units text[] := '{kg, g, mg, oz, l, ml}';
unit_key record;
from_definition jsonb;
to_definition jsonb;
local_result jsonb;
result_standard jsonb := '{}'::jsonb;
result jsonb := '{"error": null, "result": null}'::jsonb;
converted_value numeric;

BEGIN  

  IF unit = ANY(known_units) THEN

  -- 1. get the from definition of this unit;
    from_definition := definitions -> unit;

    IF unitTo IS NULL THEN
    FOR unit_key IN SELECT key, value FROM jsonb_each(definitions) LOOP
      -- unit_key is definition from definitions.
      IF unit_key.value -> 'bulkDensity' THEN
        -- to is volume
        IF from_definition -> 'bulkDensity' THEN
          -- from is volume too
          converted_value := quantity * (from_definition->>'factor')::numeric / (unit_key.value->>'factor')::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            unit,
            'toUnitName',
            unit_key.key,
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        ELSE
          -- from is mass
          converted_value := quantity * (unit_key.value->>'bulkDensity')::numeric * (from_definition->>'factor')::numeric / (unit_key.value->>'factor')::numeric;

          local_result := jsonb_build_object(
            'fromUnitName',
            unit,
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
          converted_value := quantity * (from_definition->>'bulkDensity')::numeric * (from_definition->>'factor')::numeric / (unit_key.value->>'factor')::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            unit,
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
            unit,
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
  ELSE -- unitTo is not null
    to_definition := definitions -> unitTo;

      IF to_definition -> 'bulkDensity' THEN
        -- to is volume
        IF from_definition -> 'bulkDensity' THEN
          -- from is volume too
          converted_value := quantity * (from_definition->>'factor')::numeric / (to_definition->>'factor')::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            unit,
            'toUnitName',
            to_definition->'name'->>'abbr',
            'value',
            quantity,
            'equivalentValue',
            converted_value
          );
        ELSE
          -- from is mass
          converted_value := quantity * (to_definition->>'bulkDensity')::numeric * (from_definition->>'factor')::numeric / (to_definition->>'factor')::numeric;

          local_result := jsonb_build_object(
            'fromUnitName',
            unit,
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
          converted_value := quantity * (from_definition->>'bulkDensity')::numeric * (from_definition->>'factor')::numeric / (to_definition->>'factor')::numeric;
          
          local_result := jsonb_build_object(
            'fromUnitName',
            unit,
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
            unit,
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
    
  END IF;

    result := jsonb_build_object(
      'result',
      jsonb_build_object('standard', result_standard),
      'error',
      'null'
    );
  ELSE

    -- check if customConversion is possible with @param unit
    -- inventory."customUnitVariationFunc" also does error handling for us :)
    SELECT data from inventory."customUnitVariationFunc"(quantity, unit, unitTo) into result;

  END IF;

RETURN QUERY
SELECT
  1 AS id,
  result as data;
END;

$function$

