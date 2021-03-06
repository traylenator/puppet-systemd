require 'spec_helper'

describe 'systemd::tmpfile' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) { facts }

        let(:title) { 'random_tmpfile.conf' }

        let(:params) {{
          :content => 'random stuff'
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_file("/etc/tmpfiles.d/#{title}").with(
          :ensure  => 'file',
          :content => /#{params[:content]}/,
          :mode    => '0444'
        ) }

        context 'with a bad tmpfile name' do
          let(:title) { 'test.badtype' }
          it {
            expect{
              is_expected.to compile.with_all_deps
            }.to raise_error(/expects a match for Systemd::Dropin/)
          }
        end

        context 'with a tmpfile name specified with filename' do
          let(:title) { 'test.badtype' }
          let(:params) {{
            :filename => 'goodname.conf',
            :content  => 'random stuff'
          }}
          it { is_expected.to create_file("/etc/tmpfiles.d/goodname.conf").with(
            :ensure  => 'file',
            :content => /#{params[:content]}/,
            :mode    => '0444'
          )}
        end

      end
    end
  end
end
