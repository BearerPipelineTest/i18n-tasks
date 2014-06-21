# coding: utf-8
module I18n::Tasks
  module MissingKeys

    def missing_tree(locale, compared_to = base_locale)
      if locale == compared_to
        # keys used, but not present in locale
        used_missing_keys = used_tree.key_names.reject { |key|
          key_expression?(key) || key_value?(key, locale) || ignore_key?(key, :missing)
        }
        Data::Tree::Siblings.from_key_names(used_missing_keys, parent_key: locale)
      else
        # keys present in compared_to, but not in locale
        data[compared_to].select_keys { |key, node|
          !key_value?(key, locale) && !ignore_key?(key, :missing)
        }
      end
    end

    # @param [:missing_from_base, :missing_from_locale, :eq_base] type (default nil)
    # @return [KeyGroup]
    def missing_keys(opts = {})
      locales = Array(opts[:locales]).presence || self.locales
      type    = opts[:type]
      unless type
        types = opts[:types].presence || missing_keys_types
        opts  = opts.except(:types).merge(locales: locales)
        return types.map { |t| missing_keys(opts.merge(type: t)) }.reduce(:+)
      end

      if type.to_s == 'missing_from_base'
        keys = keys_missing_from_base if locales.include?(base_locale)
      else
        keys = non_base_locales(locales).map { |locale|
          send("keys_#{type}", locale)
        }.reduce(:+)
      end
      keys || KeyGroup.new([])
    end

    def missing_keys_types
      @missing_keys_types ||= [:missing_from_base, :eq_base, :missing_from_locale]
    end

    # @return [KeyGroup] missing keys, i.e. key that are in the code but are not in the base locale data
    def keys_missing_from_base
      @keys_missing_from_base ||= begin
        KeyGroup.new missing_tree(base_locale).key_names, type: :missing_from_base, locale: base_locale
      end
    end

    # @return [KeyGroup] keys missing (nil or blank?) in locale but present in base
    def keys_missing_from_locale(locale)
      return keys_missing_from_base if locale == base_locale
      @keys_missing_from_locale         ||= {}
      @keys_missing_from_locale[locale] ||= begin
        keys = missing_tree(locale).key_names.map { |key| depluralize_key(key, locale) }.uniq
        KeyGroup.new keys, type: :missing_from_locale, locale: locale
      end
    end

    # @return [KeyGroup] keys missing value (but present in base)
    def keys_eq_base(locale)
      @keys_eq_base         ||= {}
      @keys_eq_base[locale] ||= begin
        keys = data[base_locale].keys.map { |key, node|
          key if node.value == t(key, locale) && !ignore_key?(key, :eq_base, locale)
        }.compact
        KeyGroup.new keys, type: :eq_base, locale: locale
      end
    end
  end
end
