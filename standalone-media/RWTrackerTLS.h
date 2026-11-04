#pragma once
// This plugin is tied to the pinned libtorrent ABI. Configure only from its
// network-thread added() callback, before adding any torrents to the session.
#ifdef TORRENT_USE_OPENSSL
#include <libtorrent/version.hpp>
#include <libtorrent/extensions.hpp>
#include <libtorrent/session_handle.hpp>
#include <libtorrent/aux_/session_impl.hpp>
#include <libtorrent/aux_/session_interface.hpp>
#include <openssl/ssl.h>
#include <openssl/pem.h>
#include <openssl/x509v3.h>
#include <openssl/err.h>
#include <atomic>
#include <memory>
#include <string>

static_assert(LIBTORRENT_VERSION_NUM == 10220, "Review pinned TLS context ABI before upgrading");
struct RWTrackerTLSState {
    // 0=pending,1=ready,2=invalid trust data/context; no URLs or credentials.
    std::atomic<int> status{0};
    std::atomic<int> anchors{0};
};
class RWTrackerTLS final : public libtorrent::plugin {
    std::string pem;
    std::shared_ptr<RWTrackerTLSState> result;
public:
    RWTrackerTLS(std::string trustedPEM, std::shared_ptr<RWTrackerTLSState> state)
        : pem(std::move(trustedPEM)), result(std::move(state)) {}
    void added(libtorrent::session_handle const& session) override {
        result->status.store(2);
        auto implementation=session.native_handle();
        if(!implementation)return;
        auto *context=static_cast<libtorrent::aux::session_interface*>(implementation.get())->ssl_ctx();
        if(!context)return;
        SSL_CTX *ctx=context->native_handle();
        SSL_CTX_set_verify(ctx,SSL_VERIFY_PEER|SSL_VERIFY_FAIL_IF_NO_PEER_CERT,nullptr);
        // Replace any host/default-path roots, including on error. Never fall
        // back to a different store after the requested app trust fails.
        X509_STORE *store=X509_STORE_new();
        if(!store)return;
        SSL_CTX_set_cert_store(ctx,store); // Context owns store from here.
        if(SSL_CTX_set_min_proto_version(ctx,TLS1_2_VERSION)!=1||pem.empty()||pem.size()>512*1024)return;
        std::size_t expected=0,offset=0;
        while((offset=pem.find("-----BEGIN CERTIFICATE-----",offset))!=std::string::npos){expected++;offset+=27;}
        if(expected==0||expected>256)return;
        BIO *bio=BIO_new_mem_buf(pem.data(),int(pem.size()));
        if(!bio)return;
        int count=0;bool valid=true;
        while(count<int(expected)){
            X509 *certificate=PEM_read_bio_X509(bio,nullptr,nullptr,nullptr);
            if(!certificate){valid=false;break;}
            if(X509_check_ca(certificate)<=0||X509_STORE_add_cert(store,certificate)!=1)valid=false;
            X509_free(certificate);if(!valid)break;count++;
        }
        BIO_free(bio);ERR_clear_error();
        if(!valid||count!=int(expected)){
            X509_STORE *empty=X509_STORE_new();if(empty)SSL_CTX_set_cert_store(ctx,empty);
            return;
        }
        result->anchors.store(count);result->status.store(1);
    }
};
#endif
