/* 
 
 runs on supplierItem create/update
 runs on recipeHub call with ingredients
 
 input Array<{id: ingredientId, ingredientName: ""}>
 input Array<int> optional supplierItem ids
 
 output {
 id: 1,
 data: {
 ingredientSupplierItemMatches: Array<{ingredientId, supplierItemId}>
 }
 }
 */
CREATE OR REPLACE FUNCTION inventory."matchIngredientSupplierItem"(ingredients jsonb, supplierItemInputs integer []) RETURNS SETOF crm."customerData" LANGUAGE plpgsql STABLE AS $function$
DECLARE supplier_item record;
ingredient record;
result jsonb;
arr jsonb := '[]';
matched_ingredient jsonb;
BEGIN IF supplierItemInputs IS NOT NULL THEN FOR supplier_item IN
SELECT "supplierItem".id,
  "supplierItem"."name"
FROM inventory."supplierItem"
WHERE "supplierItem".id = ANY (supplierItemInputs) LOOP
SELECT *
FROM jsonb_array_elements(ingredients) AS found_ingredient
WHERE (found_ingredient->>'ingredientName') = supplier_item.name INTO matched_ingredient;
IF matched_ingredient IS NOT NULL THEN arr := arr || jsonb_build_object(
  'ingredient',
  matched_ingredient,
  'supplierItemId',
  supplier_item.id
);
END IF;
END LOOP;
ELSE FOR supplier_item IN
SELECT "supplierItem".id,
  "supplierItem"."name"
FROM inventory."supplierItem" LOOP
SELECT *
FROM jsonb_array_elements(ingredients) AS found_ingredient
WHERE (found_ingredient->>'ingredientName') = supplier_item.name INTO matched_ingredient;
IF matched_ingredient IS NOT NULL THEN arr := arr || jsonb_build_object(
  'ingredient',
  matched_ingredient,
  'supplierItemId',
  supplier_item.id
);
END IF;
END LOOP;
END IF;
result := jsonb_build_object('ingredientSupplierItemMatches', arr);
RETURN QUERY
SELECT 1 AS id,
  result as data;
END;
$function$