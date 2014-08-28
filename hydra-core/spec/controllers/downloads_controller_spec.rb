require 'spec_helper'

describe DownloadsController do
  before do
    Rails.application.routes.draw do
      resources :downloads
      devise_for :users
      root to: 'catalog#index'
    end
  end

  describe "routing" do
    it "should route" do
      assert_recognizes( {:controller=>"downloads", :action=>"show", "id"=>"test1"}, "/downloads/test1?filename=my%20dog.jpg" )
    end
  end

  describe "with a file" do
    before do
      class ContentHolder < ActiveFedora::Base
        include Hydra::AccessControls::Permissions
        has_file_datastream 'thumbnail'
      end
      @user = User.new.tap {|u| u.email = 'email@example.com'; u.password = 'password'; u.save}
      @obj = ContentHolder.new
      @obj.label = "world.png"
      @obj.add_file_datastream('fizz', :dsid=>'buzz', :mimeType => 'image/png')
      @obj.add_file_datastream('foobarfoobarfoobar', :dsid=>'content', :mimeType => 'image/png')
      @obj.add_file_datastream("It's a stream", :dsid=>'descMetadata', :mimeType => 'text/plain')
      @obj.read_users = [@user.user_key]
      @obj.save!
    end
    after do
      @obj.destroy
      Object.send(:remove_const, :ContentHolder)
    end 
    context "when not logged in" do
      context "when a specific datastream is requested" do
        it "should redirect to the root path and display an error" do
          get "show", id: @obj.pid, datastream_id: "descMetadata"
          expect(response).to redirect_to new_user_session_path
          expect(flash[:alert]).to eq "You are not authorized to access this page."
        end
      end
    end
    context "when logged in, but without read access" do
      let(:user) { User.new.tap {|u| u.email = 'email2@example.com'; u.password = 'password'; u.save} }
      before do
        sign_in user
      end
      context "when a specific datastream is requested" do
        it "should redirect to the root path and display an error" do
          get "show", id: @obj.pid, datastream_id: "descMetadata"
          expect(response).to redirect_to root_path
          expect(flash[:alert]).to eq "You are not authorized to access this page."
        end
      end
    end

    context "when logged in as reader" do
      before do
        sign_in @user
        User.any_instance.stub(:groups).and_return([])
      end
      describe "#show" do
        it "should default to returning default download configured by object" do
          ContentHolder.stub(:default_content_ds).and_return('buzz')
          get "show", :id => @obj.pid
          response.should be_success
          response.headers['Content-Type'].should == "image/png"
          response.headers["Content-Disposition"].should == "inline; filename=\"world.png\""
          response.body.should == 'fizz'
        end
        it "should default to returning default download configured by controller" do
          DownloadsController.default_content_dsid.should == "content"
          get "show", :id => @obj.pid
          response.should be_success
          response.headers['Content-Type'].should == "image/png"
          response.headers["Content-Disposition"].should == "inline; filename=\"world.png\""
          response.body.should == 'foobarfoobarfoobar'
        end

        context "when a specific datastream is requested" do
          context "and it doesn't exist" do
            it "should return :not_found when the datastream doesn't exist" do
              get "show", :id => @obj.pid, :datastream_id => "thumbnail"
              response.should be_not_found
            end
          end
          context "and it exists" do
            it "should return it" do
              get "show", :id => @obj.pid, :datastream_id => "descMetadata"
              response.should be_success
              response.headers['Content-Type'].should == "text/plain"
              response.headers["Content-Disposition"].should == "inline; filename=\"world.png\""
              response.body.should == "It's a stream"
            end
          end
        end
        it "should support setting disposition to inline" do
          get "show", :id => @obj.pid, :disposition => "inline"
          response.should be_success
          response.headers['Content-Type'].should == "image/png"
          response.headers["Content-Disposition"].should == "inline; filename=\"world.png\""
          response.body.should == 'foobarfoobarfoobar'
        end
        it "should allow you to specify filename for download" do
          get "show", :id => @obj.pid, "filename" => "my%20dog.png"
          response.should be_success
          response.headers['Content-Type'].should == "image/png"
          response.headers["Content-Disposition"].should == "inline; filename=\"my%20dog.png\""
          response.body.should == 'foobarfoobarfoobar'
        end
      end

      describe "stream" do
        before do
          stub_response = double()
          stub_response.stub(:read_body).and_yield("one1").and_yield('two2').and_yield('thre').and_yield('four')
          stub_repo = double()
          stub_repo.stub(:datastream_dissemination).and_yield(stub_response)
          stub_ds = ActiveFedora::Datastream.new
          stub_ds.stub(:repository).and_return(stub_repo)
          stub_ds.stub(:mimeType).and_return('video/webm')
          stub_ds.stub(:dsSize).and_return(16)
          stub_ds.stub(:dsid).and_return('webm')
          stub_ds.stub(:new?).and_return(false)
          stub_ds.stub(:pid).and_return('changeme:test')
          stub_file = double('stub object', datastreams: {'webm' => stub_ds}, pid:'changeme:test', label: "MyVideo.webm")
          ActiveFedora::Base.should_receive(:load_instance_from_solr).with('changeme:test').and_return(stub_file)
          controller.stub(:authorize!).with(:download, stub_ds).and_return(true)
          controller.stub(:log_download)
        end
        it "head request" do
          request.env["HTTP_RANGE"] = 'bytes=0-15'
          head :show, id: 'changeme:test', datastream_id: 'webm'
          response.headers['Content-Length'].should == 16
          response.headers['Accept-Ranges'].should == 'bytes'
          response.headers['Content-Type'].should == 'video/webm'
        end
        it "should send the whole thing" do
          request.env["HTTP_RANGE"] = 'bytes=0-15'
          get :show, id: 'changeme:test', datastream_id: 'webm'
          response.body.should == 'one1two2threfour'
          response.headers["Content-Range"].should == 'bytes 0-15/16'
          response.headers["Content-Length"].should == '16'
          response.headers['Accept-Ranges'].should == 'bytes'
          response.headers['Content-Type'].should == "video/webm"
          response.headers["Content-Disposition"].should == "inline; filename=\"MyVideo.webm\""
          response.status.should == 206
        end
        it "should send the whole thing when the range is open ended" do
          request.env["HTTP_RANGE"] = 'bytes=0-'
          get :show, id: 'changeme:test', datastream_id: 'webm'
          response.body.should == 'one1two2threfour'
        end
        it "should get a range not starting at the beginning" do
          request.env["HTTP_RANGE"] = 'bytes=3-15'
          get :show, id: 'changeme:test', datastream_id: 'webm'
          response.body.should == '1two2threfour'
          response.headers["Content-Range"].should == 'bytes 3-15/16'
          response.headers["Content-Length"].should == '13'
        end
        it "should get a range not ending at the end" do
          request.env["HTTP_RANGE"] = 'bytes=4-11'
          get :show, id: 'changeme:test', datastream_id: 'webm'
          response.body.should == 'two2thre'
          response.headers["Content-Range"].should == 'bytes 4-11/16'
          response.headers["Content-Length"].should == '8'
        end
        context "not requesting a range" do
          it "should not stream" do
            expect(stub_ds).to receive(:content)
            expect(stub_ds).not_to receive(:stream)
            get :show, id: 'changeme:test', datastream_id: 'webm'
          end
          it "should set the Content-Length header if dsSize != 0" do
            get :show, id: 'changeme:test', datastream_id: 'webm'
            expect(response).to be_successful
            expect(response.headers["Content-Length"]).to eq "16"
          end
          it "should not set the Content-Length header if dsSize == 0" do
            allow(stub_ds).to receive(:dsSize) { 0 }
            get :show, id: 'changeme:test', datastream_id: 'webm'
            expect(response).to be_successful
            expect(response.headers).to_not include "Content-Length"
          end
        end
      end
    end

    describe "overriding the default asset param key" do
      before do
        Rails.application.routes.draw do
          scope 'objects/:object_id' do
            get 'download' => 'downloads#show'
          end
        end
        sign_in @user
      end
      it "should use the custom param value to retrieve the asset" do
        controller.stub(:asset_param_key).and_return(:object_id)
        get "show", :object_id => @obj.pid
        response.should be_successful
      end
    end

    describe "overriding the can_download? method" do
      before { sign_in @user }
      context "current_ability.can? returns true / can_download? returns false" do
        it "should authorize according to can_download?" do
          controller.current_ability.can?(:download, @obj.datastreams['buzz']).should be true
          controller.stub(:can_download?).and_return(false)
          Deprecation.silence(Hydra::Controller::DownloadBehavior) do
            get :show, id: @obj, datastream_id: 'buzz'
          end
          expect(response).to redirect_to root_url
        end
      end
      context "current_ability.can? returns false / can_download? returns true" do
        before do
          @obj.rightsMetadata.clear_permissions!
          @obj.save
        end
        it "should authorize according to can_download?" do
          controller.current_ability.can?(:download, @obj.datastreams['buzz']).should be false
          controller.stub(:can_download?).and_return(true)
          Deprecation.silence(Hydra::Controller::DownloadBehavior) do
            get :show, id: @obj, datastream_id: 'buzz'
          end
          response.should be_successful           
        end
      end
    end
  end

  describe "external datastream compatibility" do
    before(:all) do
      class ExternalContentHolder < ActiveFedora::Base
        has_file_datastream name: 'image', control_group: 'E'
      end
    end
    after(:all) do
      Object.send(:remove_const, :ExternalContentHolder)
    end
    let(:obj) { ExternalContentHolder.new }
    let(:file) { File.absolute_path(File.join(File.dirname(__FILE__), '..', 'fixtures', 'hydra_logo.png')) }
    before(:each) do
      controller.current_ability.can(:download, ExternalContentHolder)
      obj.image.dsLocation = "file:/#{URI.escape(file)}"
      obj.image.mimeType = "image/png"
      obj.save
      get :show, id: obj, datastream_id: "image"
    end
    it "should download the datastream content" do
      expect(response).to be_successful
      expect(response.response_body.length).to eq File.size(file)
    end
  end

end
