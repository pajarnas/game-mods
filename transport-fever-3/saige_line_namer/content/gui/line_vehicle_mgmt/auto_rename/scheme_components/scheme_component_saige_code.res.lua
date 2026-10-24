function data()
	return {
		type = "rename_scheme_component",
		data = {
			schemeComponentNameRaw = "saige_code",
			schemeComponentNameTranslated = _("Line Code"),
			renameFnDefinition = {
				fileName = resolve("scheme_component_saige_code.script@renameFn"),
				params = {},
			},
		},
	}
end
