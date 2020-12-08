# frozen_string_literal: true
require_relative '../test_base'
require_code 'http_proxy/languages_start_points'

module Dual
  class LanguagesStartPointsTest < TestBase

    def self.id58_prefix
      'DDx'
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    test 'as3', %w(
    LSP is alive ) do
      assert languages_start_points.alive?.is_a?(TrueClass)
    end

    test 'as4', %w(
    LSP is ready ) do
      assert languages_start_points.ready?.is_a?(TrueClass)
    end

    test 'as5', %w(
    LSP sha is SHA of git commit which created its docker image
    ) do
      assert_sha(languages_start_points.sha)
    end

    private

      def languages_start_points
        ::HttpProxy::LanguagesStartPoints.new
      end

  end
end
