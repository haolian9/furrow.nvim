my rough text-aligning impl

https://github.com/haolian9/zongzi/assets/6236829/207f9930-a653-46d2-9ea4-52cb8e865804

## design choices, features, limits
* live preview is a 'must have' feature
* utf-8 strings applicable
* preset profiles instead of user given regex

## status
* just works
* very few usecases, limited by my experiences

## prerequisites
* nvim 0.11.*
* haolian9/infra.nvim

## usage

my personal config:
```
cmds.create("Furrow", function() require("furrow.interactive")() end, { nargs = 0, range = true })
m.x("<cr>", [[:lua require"furrow.interactive"()<cr>]])
```

## about the name
'plough a lonely furrow'. 这话很是切题
