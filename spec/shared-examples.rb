begin
  require_relative 'hosts/common.rb'
rescue LoadError
  nil
end

shared_examples 'compile' do
  it { is_expected.to compile }
end

shared_examples 'show_catalog' do
  it 'shows catalog contents' do
    Noop::Utils.output Noop::Utils.separator
    Noop::Utils.output Noop.task.catalog_dump self
    Noop::Utils.output Noop::Utils.separator
  end
end

shared_examples 'status' do
  it 'shows status' do
    Noop::Utils.output Noop::Utils.separator
    Noop::Utils.output Noop.task.status_report self
    Noop::Utils.output Noop::Utils.separator
    Noop::Utils.output Noop.task.gem_versions_report
    Noop::Utils.output Noop::Utils.separator
  end
end

shared_examples 'files_installed_by_puppet' do
  it 'should check that binary files are not installed by this task' do
    Noop.catalog_file_resources_check self
  end
end

shared_examples 'save_files_list' do
  it 'should save the list of File resources to the file' do
    Noop.catalog_file_report_write self
  end
end

shared_examples 'saved_catalog' do
  it 'should save the current task catalog to the file', :if => (ENV['SPEC_CATALOG_CHECK'] == 'save') do
    Noop.file_write_task_catalog self
  end
  it 'should check the current task catalog against the saved one', :if => (ENV['SPEC_CATALOG_CHECK'] == 'check')  do
    saved_catalog = Noop.preprocess_catalog_data Noop.file_read_task_catalog
    current_catalog = Noop.preprocess_catalog_data Noop.catalog_dump self
    expect(saved_catalog).to eq current_catalog
  end
end

shared_examples 'console' do
  it 'runs pry console' do
    require 'pry'
    binding.pry
  end
end

###############################################################################

def run_test(manifest_file, *args)
  Noop.task_spec = manifest_file unless Noop.task_spec

  Noop::Config.log.progname = 'noop_spec'
  Noop::Utils.debug "RSPEC: #{Noop.task.inspect}"

  # FIXME: kludge to support calling Puppet function outside of the test context
  Noop.setup_overrides

  include FuelRelationshipGraphMatchers

  let(:task) do
    Noop.task
  end

  before(:all) do
    Noop.setup_overrides
  end

  let(:facts) do
    Noop.facts_data
  end

  let (:catalog) do
    catalog = subject
    catalog = catalog.call if catalog.is_a? Proc
  end

  let (:ral) do
    ral = catalog.to_ral
    ral.finalize
    ral
  end

  let (:graph) do
    graph = Puppet::Graph::RelationshipGraph.new(Puppet::Graph::TitleHashPrioritizer.new)
    graph.populate_from(ral)
    graph
  end

  include_examples 'compile'
  include_examples 'status' if ENV['SPEC_SHOW_STATUS']
  include_examples 'show_catalog' if ENV['SPEC_CATALOG_SHOW']
  include_examples 'console' if ENV['SPEC_RSPEC_CONSOLE']
  include_examples 'files_installed_by_puppet' if ENV['SPEC_PUPPET_BINARY_FILES']
  include_examples 'save_files_list' if ENV['SPEC_SAVE_FILE_RESOURCES']
  include_examples 'saved_catalog' if ENV['SPEC_CATALOG_CHECK']

  begin
    include_examples 'catalog'
  rescue ArgumentError
    true
  end

  begin
    it_behaves_like 'common'
  rescue ArgumentError
    true
  end

  at_exit do
    Noop.dir_path_coverage.mktree unless Noop.dir_path_coverage.directory?
    report = RSpec::Puppet::Coverage.report!
    Noop::Utils.output "Coverage:#{report[:coverage]}% (#{report[:touched]}/#{report[:total]})"
    if report[:untouched] > 0
      resources_report = "Untouched resources:\n"
      resources = report[:resources]
      if resources.is_a? Hash
        resources.each do |resource, status|
          resources_report += "* #{resource}\n" unless status['touched']
        end
      end
      Noop::Utils.output resources_report
    end
    Noop::Utils.debug "Saving coverage report to: '#{Noop.file_path_coverage_report}'"
    File.open(Noop.file_path_coverage_report, 'w') do |file|
      file.puts YAML.dump report
    end
  end if ENV['SPEC_COVERAGE']

  yield self if block_given?

end

alias :test_ubuntu_and_centos :run_test
alias :test_ubuntu :run_test
alias :test_centos :run_test
