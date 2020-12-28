/* 
 
 runs on ingredientSachet create/update
 runs on recipeHub call with sachets
 
 input Array<{id: sachetId, quantity: "", ingredientName: "", processingName: ""}>
 input Array<int> optional supplierItem ids
 
 output {
 id: 1,
 data: {
 matchedSachetIngredientSachet: Array<{sachet<payload>, ingredientSachet.id, isProcessingExactMatch}>
 }
 }
 
 same as matchSachetSupplierItem but matches the sachet quantity not the supplierItem.unitSize
 */
CREATE OR REPLACE FUNCTION inventory."matchedSachetIngredientSachet"(sachets jsonb, ingredientIds integer []) RETURNS SETOF crm."customerData" LANGUAGE plpgsql STABLE AS $function$ 
DECLARE sachet_ingredient record;
sachet record;
result jsonb;
arr jsonb := '[]';
matched_sachet jsonb;
BEGIN IF ingredientIds IS NOT NULL THEN FOR sachet_ingredient IN 
-- select all sachets from ingreident.ingredientSachet
-- join ingredientProcessing and ingredient
-- filter out sachets with no quantity
-- filter in ingredients in ingredientIds
SELECT
  "ingredientSachet".id,
  quantity,
  "processingName",
  name
FROM
  ingredient."ingredientSachet"
  JOIN ingredient."ingredientProcessing" ON "ingredientProcessingId" = "ingredientProcessing".id
  JOIN ingredient.ingredient ON "ingredientSachet"."ingredientId" = ingredient.id
WHERE
  "ingredientSachet"."quantity" IS NOT NULL
  AND "ingredientProcessing"."processingName" IS NOT NULL
  AND "ingredient".id = ANY (ingredientIds) LOOP
SELECT
  *
FROM
  jsonb_array_elements(sachets) AS found_sachet
WHERE
  (found_sachet ->> 'quantity') :: int = sachet_ingredient."quantity"
  AND (found_sachet ->> 'processingName') = sachet_ingredient."processingName"
  AND (found_sachet ->> 'ingredientName') = sachet_ingredient.name INTO matched_sachet;
IF matched_sachet IS NOT NULL THEN arr := arr || jsonb_build_object(
    'sachet',
    matched_sachet,
    'ingredientSachetId',
    sachet_ingredient.id,
    'isProcessingExactMatch',
    true
  );
END IF;
END LOOP;
ELSE FOR sachet_ingredient IN
SELECT
  "ingredientSachet".id,
  quantity,
  "processingName",
  name
FROM
  ingredient."ingredientSachet"
  JOIN ingredient."ingredientProcessing" ON "ingredientProcessingId" = "ingredientProcessing".id
  JOIN ingredient.ingredient ON "ingredientSachet"."ingredientId" = ingredient.id
WHERE
  "ingredientSachet"."quantity" IS NOT NULL
  AND "ingredientProcessing"."processingName" IS NOT NULL LOOP
SELECT
  *
FROM
  jsonb_array_elements(sachets) AS found_sachet
WHERE
  (found_sachet ->> 'quantity') :: int = sachet_ingredient."quantity"
  AND (found_sachet ->> 'processingName') = sachet_ingredient."processingName"
  AND (found_sachet ->> 'ingredientName') = sachet_ingredient.name INTO matched_sachet;
IF matched_sachet IS NOT NULL THEN arr := arr || jsonb_build_object(
    'sachet',
    matched_sachet,
    'ingredientSachetId',
    sachet_ingredient.id,
    'isProcessingExactMatch',
    true
  );
END IF;
END LOOP;
END IF;
result := jsonb_build_object('sachetIngredientSachetMatches', arr);
RETURN QUERY
SELECT
  1 AS id,
  result as data;
END;
$function$
