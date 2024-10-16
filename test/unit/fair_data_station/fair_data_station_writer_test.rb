require 'test_helper'

class FairDataStationWriterTest < ActiveSupport::TestCase
  test 'construct seek isa' do
    path = "#{Rails.root}/test/fixtures/files/fairdatastation/demo.ttl"
    inv = Seek::FairDataStation::Reader.new.parse_graph(path).first
    policy = FactoryBot.create(:public_policy)

    contributor = FactoryBot.create(:person)
    project = contributor.projects.first
    FactoryBot.create(:experimental_assay_class)
    FactoryBot.create(:fairdatastation_virtual_demo_sample_type)

    investigation = Seek::FairDataStation::Writer.new.construct_isa(inv, contributor, [project], policy)
    studies = investigation.studies.to_a
    obs_units = studies.first.observation_units.to_a
    assays = studies.first.assays.to_a
    data_files = assays.first.assay_assets.to_a.collect(&:asset).select { |a| a.is_a?(DataFile) }
    samples = obs_units.first.samples.to_a

    assay_samples = assays.collect { |a| a.samples.to_a }.flatten
    assert_equal 9, assay_samples.count
    assert_equal samples, (assay_samples & samples)

    assert_equal 1, studies.count
    assert_equal 9, assays.count
    assert_equal 2, data_files.count
    assert_equal 2, obs_units.count
    assert_equal 4, samples.count

    assert_equal Policy::MANAGING, investigation.policy.access_type
    assert_equal Policy::MANAGING, studies.first.policy.access_type
    assert_equal Policy::MANAGING, obs_units.first.policy.access_type
    assert_equal Policy::MANAGING, assays.first.policy.access_type
    assert_equal Policy::MANAGING, samples.first.policy.access_type
    assert_equal Policy::MANAGING, data_files.first.policy.access_type

    refute_equal investigation.policy, studies.first.policy
    refute_equal investigation.policy, obs_units.first.policy
    refute_equal investigation.policy, assays.first.policy
    refute_equal investigation.policy, samples.first.policy
    refute_equal investigation.policy, data_files.first.policy

    assert investigation.valid?
    assert studies.first.valid?

    pp assays.first.errors unless assays.first.valid?
    assert assays.first.valid?

    pp data_files.first.errors unless data_files.first.valid?
    assert data_files.first.valid?

    assert_equal 'INV_DRP007092', investigation.external_identifier
    assert_equal 'DRP007092', studies.first.external_identifier
    assert_equal 'DRR243856', assays.first.external_identifier
    assert_equal 'DRR243856_1.fastq.gz', data_files.first.external_identifier
    assert_equal 'HIV-1_positive', obs_units.first.external_identifier
    assert_equal 'DRS176892', samples.first.external_identifier

    assert_difference('Investigation.count', 1) do
      assert_difference('Study.count', 1) do
        assert_difference('ObservationUnit.count', 2) do
          assert_difference('Sample.count', 9) do
            assert_difference('Assay.count', 9) do
              assert_difference('AssayAsset.count', 27) do
                assert_difference('DataFile.count', 18) do
                  User.with_current_user(contributor.user) do
                    investigation.save!
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test 'populate extended metadata and samples' do
    study_metadata_type = FactoryBot.create(:fairdata_virtual_demo_study_extended_metadata)
    FactoryBot.create(:study_extended_metadata_type)
    FactoryBot.create(:fairdata_virtual_demo_study_extended_metadata_partial)
    assay_metadata_type = FactoryBot.create(:fairdata_virtual_demo_assay_extended_metadata)
    FactoryBot.create(:simple_assay_extended_metadata_type)
    FactoryBot.create(:simple_investigation_extended_metadata_type_with_description_and_label)
    FactoryBot.create(:experimental_assay_class)
    sample_type = FactoryBot.create(:fairdatastation_virtual_demo_sample_type)

    path = "#{Rails.root}/test/fixtures/files/fairdatastation/demo.ttl"
    inv = Seek::FairDataStation::Reader.new.parse_graph(path).first
    contributor = FactoryBot.create(:person)
    project = contributor.projects.first

    investigation = Seek::FairDataStation::Writer.new.construct_isa(inv, contributor, [project], Policy.default)
    assert_nil investigation.extended_metadata

    study = investigation.studies.first
    refute_nil study.extended_metadata
    assert_equal study_metadata_type, study.extended_metadata.extended_metadata_type

    assert_equal 'DRP007092', study.extended_metadata.get_attribute_value('Alias')
    assert_equal 'NIID', study.extended_metadata.get_attribute_value('Centre Name')
    assert_equal 'human gut metagenome', study.extended_metadata.get_attribute_value('Centre Project Name')
    assert_equal 'PRJDB10485', study.extended_metadata.get_attribute_value('External Ids')
    assert_equal 'DRA010770', study.extended_metadata.get_attribute_value('Submission Accession')
    assert_equal 'DRA010770', study.extended_metadata.get_attribute_value('Submission Alias')
    assert_equal 'AIDS Research Center2022-8-31', study.extended_metadata.get_attribute_value('Submission Lab Name')

    assay = study.assays.first
    refute_nil assay.extended_metadata
    assert_equal assay_metadata_type, assay.extended_metadata.extended_metadata_type

    assert_equal 'NMIMR', assay.extended_metadata.get_attribute_value('Facility')
    assert_equal 'CCTACGGGNGGCWGCAG', assay.extended_metadata.get_attribute_value('Forward Primer')
    assert_equal 'Illumina MiSeq', assay.extended_metadata.get_attribute_value('Instrument Model')
    assert_equal 'PCR', assay.extended_metadata.get_attribute_value('Library Selection')
    assert_equal 'METAGENOMIC', assay.extended_metadata.get_attribute_value('Library Source')
    assert_equal 'AMPLICON', assay.extended_metadata.get_attribute_value('Library Strategy')

    study.assays.each do |assay|
      assert assay.valid?, "invalid assay - #{assay.errors.full_messages}"
    end
    assert study.valid?, "invalid study - #{study.errors.full_messages}"
    assert investigation.valid?, "invalid investigation - #{investigation.errors.full_messages}"

    assert_difference('ExtendedMetadata.count', 10) do
      User.with_current_user(contributor.user) do
        study.save!
      end
    end

    sample = study.observation_units.first.samples.first
    refute_nil sample.sample_type
    assert_equal sample_type, sample.sample_type
    assert_equal 'sample DRS176892', sample.title
    assert_equal 'Sample obtained from Single age 30 collected on 2017-09-13 from the human gut',
                 sample.get_attribute_value('Description')
    assert_equal 'Homo sapiens', sample.get_attribute_value('Host')
    assert_equal 'HIV-1 positive', sample.get_attribute_value('Host disease stat')
    assert_equal 'Single', sample.get_attribute_value('Marital status')
    assert_equal 'Trader', sample.get_attribute_value('Occupation')
    assert_equal 'human gut metagenome', sample.get_attribute_value('Scientific name')
    assert_equal '408170', sample.get_attribute_value('Organism')
  end

  test 'observation_unit and assay datasets created in construct_isa' do
    path = "#{Rails.root}/test/fixtures/files/fairdatastation/seek-fair-data-station-test-case.ttl"
    inv = Seek::FairDataStation::Reader.new.parse_graph(path).first

    contributor = FactoryBot.create(:person)
    project = contributor.projects.first
    FactoryBot.create(:experimental_assay_class)
    FactoryBot.create(:fairdatastation_test_case_sample_type)

    investigation = Seek::FairDataStation::Writer.new.construct_isa(inv, contributor, [project], Policy.default)
    assert_equal 2, investigation.studies.last.observation_units.to_a.count
    observation_unit = investigation.studies.last.observation_units.first
    assert_equal 1, observation_unit.observation_unit_assets.find_all { |oua|
                      oua.asset_type == 'DataFile'
                    }.collect(&:asset).count

    df = observation_unit.observation_unit_assets.find_all { |oua| oua.asset_type == 'DataFile' }.first.asset
    assert_equal 'Dataset: test-file-1.csv', df.title
    assert_equal 'file', df.description
    assert_equal 'application/octet-stream', df.content_blob.content_type
    assert df.content_blob.external_link?
    assert df.content_blob.is_webpage?
    assert df.content_blob.show_as_external_link?

    assay = investigation.studies.last.assays.last
    assert_equal 'Assay - seek-test-assay-6', assay.title
    assert_equal 1, assay.assay_assets.find_all { |oua| oua.asset_type == 'DataFile' }.collect(&:asset).count
    df = assay.assay_assets.find_all { |oua| oua.asset_type == 'DataFile' }.first.asset
    assert_equal 'Dataset: test-file-3.csv', df.title
    assert_equal 'file', df.description
    assert_equal 'application/octet-stream', df.content_blob.content_type
    assert df.content_blob.external_link?
    assert df.content_blob.is_webpage?
    assert df.content_blob.show_as_external_link?

    assert_difference('DataFile.count', 5) do
      assert_difference('ObservationUnitAsset.count', 3) do
        disable_authorization_checks do
          investigation.save!
        end
      end
    end

    # check dataset linked to multiple cases
    df = DataFile.where(external_identifier: 'test-file-1.csv').first
    assert_equal %w[seek-test-obs-unit-1 seek-test-obs-unit-2],
                 df.observation_units.collect(&:external_identifier).sort
    assert_equal ['seek-test-assay-1'], df.assays.collect(&:external_identifier).sort
    df = DataFile.where(external_identifier: 'test-file-3.csv').first
    assert_empty df.observation_units
    assert_equal %w[seek-test-assay-3 seek-test-assay-6], df.assays.collect(&:external_identifier).sort
  end

  test 'populate obsv unit extended metadata' do
    ext_metadata_type = FactoryBot.create(:fairdata_test_case_obsv_unit_extended_metadata)
    FactoryBot.create(:experimental_assay_class)

    path = "#{Rails.root}/test/fixtures/files/fairdatastation/seek-fair-data-station-test-case.ttl"
    inv = Seek::FairDataStation::Reader.new.parse_graph(path).first
    contributor = FactoryBot.create(:person)
    project = contributor.projects.first

    investigation = Seek::FairDataStation::Writer.new.construct_isa(inv, contributor, [project], Policy.default)
    assert_nil investigation.extended_metadata

    assert_difference('ExtendedMetadata.count', 3) do
      User.with_current_user(contributor.user) do
        investigation.save!
      end
    end

    assert_equal 2, investigation.studies.count
    study = investigation.studies.first
    assert_equal 1, study.observation_units.count
    obvs_unit = study.observation_units.first
    refute_nil obvs_unit.extended_metadata
    assert_equal ext_metadata_type, obvs_unit.extended_metadata.extended_metadata_type

    assert_equal '1234g', obvs_unit.extended_metadata.get_attribute_value('Birth weight')
    assert_equal 'male', obvs_unit.extended_metadata.get_attribute_value('Gender')
    assert_equal '2020-01-10', obvs_unit.extended_metadata.get_attribute_value('Date of birth')
  end
end
