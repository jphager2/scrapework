# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'
require 'active_attr'
require 'active_support/all'

module Scrapework
  # Base class for web data type
  class Object
    include ActiveAttr::Model

    attribute :url

    def self.reflections
      @reflections ||= {}
    end

    # rubocop:disable Metrics/MethodLength
    def self.belongs_to(object, options = {})
      ivar = "@#{object}"
      mapped_method = "_mapped_#{object}"
      reflection_class = options.fetch(:class) { object.to_s.classify }.to_s

      define_method(object) do
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)

        attributes = __send__(mapped_method)
        return if attributes.nil?

        instance = reflection_class.constantize.new(attributes)
        instance_variable_set(ivar, instance)
      end

      reflections[object] = { type: 'belongs_to', class: reflection_class }
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Naming/PredicateName
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def self.has_many(objects, options = {})
      ivar = "@#{objects}"
      reflection_class = options.fetch(:class) do
        objects.to_s.singularize.classify
      end.to_s
      inverse_reflection = self.class.name.underscore

      define_method(objects) do
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)

        instances = __send__("_mapped_#{objects}").map do |attributes|
          next if attributes.nil?

          instance = reflection_class.constantize.new(attributes)
          if instance.class.reflections.include?(inverse_reflection)
            instance.public_send("#{inverse_reflection}=", self)
          end
          instance
        end
        instance_variable_set(ivar, instances.compact)
      end

      reflections[objects] = { type: 'has_many', class: reflection_class }
    end
    # rubocop:enable Naming/PredicateName
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Naming/PredicateName
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def self.has_one(object, options = {})
      ivar = "@#{object}"
      mapped_method = "_mapped_#{object}"
      reflection_class = options.fetch(:class) { object.to_s.classify }.to_s
      inverse_reflection = self.class.name.underscore

      define_method(object) do
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)

        attributes = __send__(mapped_method)
        return if attributes.nil?

        instance = reflection_class.constantize.new(attributes)
        if instance.class.reflections.include?(inverse_reflection)
          instance.public_send("#{inverse_reflection}=", self)
        end
        instance_variable_set(ivar, instance)
      end

      reflections[object] = { type: 'has_one', class: reflection_class }
    end
    # rubocop:enable Naming/PredicateName
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    def self.paginate(&block)
      mapped_method = :_mapped_pagination

      map(:pagination, &block)

      define_method(:prev_page) do
        pages = __send__(mapped_method)
        self.class.new(pages[0]) if pages[0]
      end

      define_method(:next_page) do
        pages = __send__(mapped_method)
        self.class.new(pages[1]) if pages[1]
      end
    end

    def self.map(name, &block)
      mapped_method = :"_mapped_#{name}"

      attr_writer name unless attributes.key?(name.to_s)

      define_method(mapped_method) do
        value = instance_exec(_document, &block)

        public_send("#{name}=", value)
      end
      private mapped_method
    end

    def self.load(url)
      instance = new(url: url)
      instance.load
      instance
    end

    def _document
      @_document ||= Nokogiri::HTML(html)
    end

    def html
      uri = URI.parse(url)
      uri.read
    end

    def load
      attributes.except('url').each do |attribute, value|
        __send__("_mapped_#{attribute}") if value.nil?
      end
    end
  end
end
