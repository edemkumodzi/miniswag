# frozen_string_literal: true

require 'test_helper'

class ConfigurationTest < Minitest::Test
  def setup
    @config = Miniswag::Configuration.new
  end

  # ── Defaults ──────────────────────────────────────────────────────────

  def test_defaults
    assert_nil @config.openapi_root
    assert_equal({}, @config.openapi_specs)
    assert_equal :json, @config.openapi_format
    assert_equal false, @config.openapi_all_properties_required
    assert_equal false, @config.openapi_no_additional_properties
  end

  # ── openapi_root ──────────────────────────────────────────────────────

  def test_validate_raises_without_openapi_root
    @config.openapi_specs = { 'v1.json' => { openapi: '3.0' } }
    error = assert_raises(Miniswag::ConfigurationError) { @config.validate! }
    assert_match(/openapi_root/, error.message)
  end

  # ── openapi_specs ─────────────────────────────────────────────────────

  def test_validate_raises_without_openapi_specs
    @config.openapi_root = '/tmp'
    @config.openapi_specs = {}
    error = assert_raises(Miniswag::ConfigurationError) { @config.validate! }
    assert_match(/openapi_specs/, error.message)
  end

  def test_validate_raises_with_nil_openapi_specs
    @config.openapi_root = '/tmp'
    @config.openapi_specs = nil
    error = assert_raises(Miniswag::ConfigurationError) { @config.validate! }
    assert_match(/openapi_specs/, error.message)
  end

  # ── openapi_format ────────────────────────────────────────────────────

  def test_validate_raises_with_unknown_format
    @config.openapi_root = '/tmp'
    @config.openapi_specs = { 'v1.json' => { openapi: '3.0' } }
    @config.openapi_format = :xml
    error = assert_raises(Miniswag::ConfigurationError) { @config.validate! }
    assert_match(/openapi_format/, error.message)
  end

  def test_validate_accepts_json_format
    @config.openapi_root = '/tmp'
    @config.openapi_specs = { 'v1.json' => { openapi: '3.0' } }
    @config.openapi_format = :json
    @config.validate! # should not raise
  end

  def test_validate_accepts_yaml_format
    @config.openapi_root = '/tmp'
    @config.openapi_specs = { 'v1.yaml' => { openapi: '3.0' } }
    @config.openapi_format = :yaml
    @config.validate! # should not raise
  end

  # ── get_openapi_spec ──────────────────────────────────────────────────

  def test_get_openapi_spec_returns_first_when_name_nil
    spec = { openapi: '3.0' }
    @config.openapi_specs = { 'v1.json' => spec }
    assert_equal spec, @config.get_openapi_spec(nil)
  end

  def test_get_openapi_spec_returns_named_spec
    spec1 = { openapi: '3.0', info: { title: 'V1' } }
    spec2 = { openapi: '3.0', info: { title: 'V2' } }
    @config.openapi_specs = { 'v1.json' => spec1, 'v2.json' => spec2 }
    assert_equal spec2, @config.get_openapi_spec('v2.json')
  end

  def test_get_openapi_spec_raises_for_unknown_name
    @config.openapi_specs = { 'v1.json' => { openapi: '3.0' } }
    error = assert_raises(Miniswag::ConfigurationError) { @config.get_openapi_spec('v99.json') }
    assert_match(/Unknown openapi_spec/, error.message)
  end

  # ── dry_run ───────────────────────────────────────────────────────────

  def test_dry_run_defaults_to_true
    assert_equal true, @config.dry_run
  end

  def test_dry_run_respects_env_var_1
    original = ENV['MINISWAG_DRY_RUN']
    ENV['MINISWAG_DRY_RUN'] = '1'
    config = Miniswag::Configuration.new
    assert_equal true, config.dry_run
  ensure
    original ? ENV['MINISWAG_DRY_RUN'] = original : ENV.delete('MINISWAG_DRY_RUN')
  end

  def test_dry_run_respects_env_var_0
    original = ENV['MINISWAG_DRY_RUN']
    ENV['MINISWAG_DRY_RUN'] = '0'
    config = Miniswag::Configuration.new
    assert_equal false, config.dry_run
  ensure
    original ? ENV['MINISWAG_DRY_RUN'] = original : ENV.delete('MINISWAG_DRY_RUN')
  end

  # ── Setters ───────────────────────────────────────────────────────────

  def test_all_properties_required_setter
    @config.openapi_all_properties_required = true
    assert_equal true, @config.openapi_all_properties_required
  end

  def test_no_additional_properties_setter
    @config.openapi_no_additional_properties = true
    assert_equal true, @config.openapi_no_additional_properties
  end
end
