-- systems/emptymodel/system.lua
-- TEMPLATE for you to fill with the rules of a system you play
-- (for example, GURPS or D&D). Copy this folder, rename it, change the 'id'
-- to the same folder name and replace the items marked with TODO
-- with the rules from the book.
--
-- The values below are GENERIC and do not represent any real system.

return {
    id = "emptymodel", -- TODO: same name of the folder
    name = "Empty Model (fill up)",
    version = "0",

    attributes = {
        -- TODO: one item per system attribute, with limits from the book.
        { id = "attr1", label = "Attribute 1", min = 0, max = 5, default = 1 },
        { id = "attr2", label = "Attribute 2", min = 0, max = 5, default = 1 },
    },

    resources = {
        -- TODO: hit points, mana, etc. 'max' is a formula based on ch.attrs.
        { id = "hp", label = "HP", max = function(ch) return 5 + ch.attrs.attr1 end },
    },

    derived = {
        -- TODO: calculated values you want to see on the sheet.
        { id = "sum", label = "Attr1 + Attr2", calc = function(ch) return ch.attrs.attr1 + ch.attrs.attr2 end },
    },

    actions = {
        -- TODO: one action per type of system roll/test.
        {
            id = "test_attr1",
            label = "Test Attribute 1",
            run = function(ch, ctx)
                local total = ctx.roll("1d6+" .. ch.attrs.attr1)
                return "result " .. total
            end,
        },
    },
}
