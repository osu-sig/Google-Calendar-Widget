require 'spec_helper'
require_relative '../../models/gcal'

describe Gcal do
  subject { Gcal }
  its(:ancestors) { is_expected.to include(Base) }


  context 'using stubs', functional: true do
    before { with_config_file('gcal/config.json') }
    let(:gcal) { Gcal.new }

    describe 'after initialization' do
      describe '@max_per_tile' do
        subject { gcal.instance_variable_get(:@max_per_tile) }
        it { is_expected.to be >= 0 }
        it { is_expected.to be_integer }
      end

      describe '@student_calendar_days' do
        subject { gcal.instance_variable_get(:@student_calendar_days) }
        it { is_expected.to be >= 0 }
        it { is_expected.to be_integer }
      end

      describe '@staff_calendar_days' do
        subject { gcal.instance_variable_get(:@staff_calendar_days) }
        it { is_expected.to be >= 0 }
        it { is_expected.to be_integer }
      end

      describe '@show_day_of_week' do
        it 'should be true or false' do
          expect([true, false]).to include(gcal.instance_variable_get(:@show_day_of_week))
        end
      end
    end



    describe 'student_schedule' do
      context 'with no events' do
        before(:each) do
          allow_any_instance_of(Gcal).to receive(:get) do
            {
              "data" => {
                "totalResults" => 0,
                "items" => []
              }
            }
          end
        end
        let(:response) { gcal.student_schedule }
        subject { response }
        its(:keys) { is_expected.to include(:entries, :conditional_more_info, :error) }
        its([:error]) { is_expected.to eq false }

        describe ':entries' do
          subject { response[:entries] }
          its(:class) { is_expected.to eq Array }
          its(:length) { is_expected.to eq 0 }
        end

        describe ':conditional_more_info' do
          subject { response[:conditional_more_info] }
          its(:class) { is_expected.to eq String }
          it { is_expected.to_not be_blank }
        end
      end


      context 'with event count' do
        before(:each) do
          allow(gcal).to receive(:get).and_return(load_json_data('gcal/events.json'))
        end

        context '<= @max_per_tile' do
          let(:response) do
            gcal.instance_variable_set(:@max_per_tile, 3)
            gcal.student_schedule
          end
          subject { response }
          its(:keys) { is_expected.to include(:entries, :conditional_more_info, :error) }
          its([:error]) { is_expected.to eq false }

          describe ':entries' do
            subject { response[:entries] }
            its(:class) { is_expected.to eq Array }
            its(:length) { is_expected.to eq 3 }

            it 'follows a specific format' do
              response[:entries].each do |entry|
                expect(entry.keys).to include(:label, :value)
                expect(entry[:label]).to_not be_blank
                expect(entry[:value]).to_not be_blank
              end
            end
          end

          describe ':conditional_more_info' do
            subject { response[:conditional_more_info] }
            its(:class) { is_expected.to eq String }
            it { is_expected.to be_blank }
          end
        end


        context '> @max_per_tile' do
          let(:response) do
            gcal.instance_variable_set(:@max_per_tile, 2)
            gcal.student_schedule
          end
          subject { response }
          its(:keys) { is_expected.to include(:entries, :conditional_more_info, :error) }
          its([:error]) { is_expected.to eq false }


          describe ':entries' do
            subject { response[:entries] }
            its(:class) { is_expected.to eq Array }
            its(:length) { is_expected.to eq 1 }

            it 'follows a specific format' do
              response[:entries].each do |entry|
                expect(entry.keys).to include(:label, :value)
                expect(entry[:label]).to_not be_blank
                expect(entry[:value]).to_not be_blank
              end
            end
          end

          describe ':conditional_more_info' do
            subject { response[:conditional_more_info] }
            its(:class) { is_expected.to eq String }
            it { is_expected.to_not be_blank }
            it { is_expected.to eq "Showing 1 of 3 events" }
          end
        end
      end
    end
  end




  context 'using live data', live: true do
    let(:gcal) { Gcal.new }

    describe 'student_schedule' do
      let(:response) { gcal.student_schedule }

      it 'gets_schedule' do
        expect(response.keys).to include(:entries, :conditional_more_info, :error)
        expect(response[:entries].class).to eq Array
        expect(response[:conditional_more_info].class).to eq String
        expect(response[:error]).to eq false
      end
    end


    # Should stub some responses so we can hit all branches in the code
    describe 'staff_outages' do
      let(:response) { gcal.staff_outages }

      it 'gets_outages' do
        expect(response.keys).to include(:entries, :conditional_more_info, :error)
        expect(response[:entries].class).to eq Array
        expect(response[:conditional_more_info].class).to eq String
        expect(response[:error]).to eq false
      end
    end
  end
end