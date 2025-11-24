use aes::cipher::{KeyIvInit, StreamCipher};
use flutter_rust_bridge::*;
use hmac::Mac as hmacmac;
use pbkdf2::pbkdf2_array;
use sha2::{Digest, Sha256, Sha512};
use std::ops::Deref;
pub use std::sync::RwLock;
pub use std::vec::Vec;
use vodozemac::base64_encode;
pub use vodozemac::{
    base64_decode,
    megolm::{
        GroupSession, GroupSessionPickle, InboundGroupSession, InboundGroupSessionPickle,
        SessionConfig as MegolmSessionConfig,
    },
    olm::{
        Account, AccountPickle, IdentityKeys, OlmMessage, Session,
        SessionConfig as OlmSessionConfig, SessionPickle,
    },
    pk_encryption::{Message as PkMessage, PkDecryption, PkEncryption},
    sas::{EstablishedSas, Mac, Sas},
    Curve25519PublicKey, Curve25519SecretKey, Ed25519PublicKey, Ed25519SecretKey, Ed25519Signature,
};
//#[frb(mirror(IdentityKeys))]
//pub struct _IdentityKeys {
//    /// The ed25519 key, used for signing.
//    pub ed25519: Ed25519PublicKey,
//    /// The curve25519 key, used for to establish shared secrets.
//    pub curve25519: Curve25519PublicKey,
//}
pub struct VodozemacMegolmSessionConfig {
    pub config: RustOpaqueNom<MegolmSessionConfig>,
}

impl From<MegolmSessionConfig> for VodozemacMegolmSessionConfig {
    fn from(config: MegolmSessionConfig) -> Self {
        Self {
            config: RustOpaqueNom::new(config),
        }
    }
}

impl VodozemacMegolmSessionConfig {
    pub fn version(&self) -> u8 {
        self.config.version()
    }

    pub fn version_1() -> Self {
        MegolmSessionConfig::version_1().into()
    }

    pub fn version_2() -> Self {
        MegolmSessionConfig::version_2().into()
    }

    // can't name this default, because that is a dart keyword and the generator also strips my
    // suffixes!
    pub fn def() -> Self {
        MegolmSessionConfig::default().into()
    }
}

pub struct VodozemacGroupSession {
    pub session: RustOpaqueNom<RwLock<GroupSession>>,
}

impl From<GroupSession> for VodozemacGroupSession {
    fn from(session: GroupSession) -> Self {
        Self {
            session: RustOpaqueNom::new(RwLock::new(session)),
        }
    }
}

impl VodozemacGroupSession {
    pub fn new(config: VodozemacMegolmSessionConfig) -> Self {
        GroupSession::new(*config.config).into()
    }

    pub fn session_id(&self) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .session_id()
    }

    pub fn message_index(&self) -> u32 {
        self.session
            .read()
            .expect("Failed to read session")
            .message_index()
    }

    pub fn session_config(&self) -> VodozemacMegolmSessionConfig {
        self.session
            .read()
            .expect("Failed to read session")
            .session_config()
            .into()
    }

    // In theory we could return more info, but the old olm API does not and currently we don't
    // need it.
    pub fn encrypt(&self, plaintext: String) -> String {
        self.session
            .write()
            .expect("Failed to write session")
            .encrypt(plaintext)
            .to_base64()
    }

    pub fn session_key(&self) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .session_key()
            .to_base64()
    }

    pub fn pickle_encrypted(&self, pickle_key: [u8; 32usize]) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .pickle()
            .encrypt(&pickle_key)
    }

    pub fn from_pickle_encrypted(
        pickle: String,
        pickle_key: [u8; 32usize],
    ) -> anyhow::Result<Self> {
        Ok(Self {
            session: RustOpaqueNom::new(RwLock::new(GroupSession::from(
                GroupSessionPickle::from_encrypted(&pickle, &pickle_key)?,
            ))),
        })
    }

    pub fn from_olm_pickle_encrypted(pickle: String, pickle_key: Vec<u8>) -> anyhow::Result<Self> {
        Ok(Self {
            session: RustOpaqueNom::new(RwLock::new(GroupSession::from_libolm_pickle(
                &pickle,
                &pickle_key,
            )?)),
        })
    }

    pub fn to_inbound(&self) -> VodozemacInboundGroupSession {
        let session = self.session.read().expect("Failed to read session");
        InboundGroupSession::from(session.deref()).into()
    }
}

pub struct VodozemacInboundGroupSession {
    pub session: RustOpaqueNom<RwLock<InboundGroupSession>>,
}

impl From<InboundGroupSession> for VodozemacInboundGroupSession {
    fn from(session: InboundGroupSession) -> Self {
        Self {
            session: RustOpaqueNom::new(RwLock::new(session)),
        }
    }
}

pub struct DecryptResult(pub String, pub u32);

impl VodozemacInboundGroupSession {
    pub fn new(session_key: String, config: VodozemacMegolmSessionConfig) -> anyhow::Result<Self> {
        Ok(InboundGroupSession::new(
            &vodozemac::megolm::SessionKey::from_base64(&session_key)?,
            *config.config,
        )
        .into())
    }

    pub fn session_id(&self) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .session_id()
    }

    pub fn first_known_index(&self) -> u32 {
        self.session
            .read()
            .expect("Failed to read session")
            .first_known_index()
    }

    // In theory we could return more info, but the old olm API does not and currently we don't
    // need it.
    pub fn decrypt(&self, encrypted: String) -> anyhow::Result<DecryptResult> {
        let temp = self
            .session
            .write()
            .expect("Failed to write session")
            .decrypt(&(vodozemac::megolm::MegolmMessage::from_base64(&encrypted)?))?;
        Ok(DecryptResult(
            String::from_utf8(temp.plaintext)?,
            temp.message_index,
        ))
    }

    pub fn pickle_encrypted(&self, pickle_key: [u8; 32usize]) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .pickle()
            .encrypt(&pickle_key)
    }

    pub fn from_pickle_encrypted(
        pickle: String,
        pickle_key: [u8; 32usize],
    ) -> anyhow::Result<Self> {
        Ok(Self {
            session: RustOpaqueNom::new(RwLock::new(InboundGroupSession::from(
                InboundGroupSessionPickle::from_encrypted(&pickle, &pickle_key)?,
            ))),
        })
    }

    pub fn from_olm_pickle_encrypted(pickle: String, pickle_key: Vec<u8>) -> anyhow::Result<Self> {
        Ok(Self {
            session: RustOpaqueNom::new(RwLock::new(InboundGroupSession::from_libolm_pickle(
                &pickle,
                &pickle_key,
            )?)),
        })
    }

    pub fn import(
        exported_session_key: String,
        config: VodozemacMegolmSessionConfig,
    ) -> anyhow::Result<Self> {
        Ok(Self {
            session: RustOpaqueNom::new(RwLock::new(InboundGroupSession::import(
                &vodozemac::megolm::ExportedSessionKey::from_base64(&exported_session_key)?,
                *config.config,
            ))),
        })
    }

    pub fn export_at_first_known_index(&self) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .export_at_first_known_index()
            .to_base64()
    }

    pub fn export_at(&self, index: u32) -> Option<String> {
        self.session
            .write()
            .expect("Failed to write session")
            .export_at(index)
            .map(|s| s.to_base64())
    }
}

pub struct VodozemacOlmSessionConfig {
    pub config: RustOpaqueNom<OlmSessionConfig>,
}

impl From<OlmSessionConfig> for VodozemacOlmSessionConfig {
    fn from(config: OlmSessionConfig) -> Self {
        Self {
            config: RustOpaqueNom::new(config),
        }
    }
}

impl VodozemacOlmSessionConfig {
    pub fn version(&self) -> u8 {
        self.config.version()
    }

    pub fn version_1() -> Self {
        OlmSessionConfig::version_1().into()
    }

    pub fn version_2() -> Self {
        OlmSessionConfig::version_2().into()
    }

    // can't name this default, because that is a dart keyword and the generator also strips my
    // suffixes!
    pub fn def() -> Self {
        OlmSessionConfig::default().into()
    }
}

pub struct VodozemacEd25519Signature {
    pub signature: RustOpaqueNom<Ed25519Signature>,
}

impl From<Ed25519Signature> for VodozemacEd25519Signature {
    fn from(signature: Ed25519Signature) -> Self {
        Self {
            signature: RustOpaqueNom::new(signature),
        }
    }
}

impl VodozemacEd25519Signature {
    pub const LENGTH: usize = 64usize;

    pub fn from_slice(bytes: [u8; 64usize]) -> anyhow::Result<Self> {
        let key = Ed25519Signature::from_slice(&bytes)?;
        Ok(key.into())
    }

    pub fn from_base64(signature: String) -> anyhow::Result<Self> {
        let key = Ed25519Signature::from_base64(&signature)?;
        Ok(key.into())
    }

    pub fn to_base64(&self) -> String {
        self.signature.to_base64()
    }

    pub fn to_bytes(&self) -> [u8; 64usize] {
        self.signature.to_bytes()
    }
}

pub struct VodozemacEd25519PublicKey {
    pub key: RustOpaqueNom<Ed25519PublicKey>,
}

impl VodozemacEd25519PublicKey {
    pub const LENGTH: usize = 32usize;

    pub fn from_slice(bytes: [u8; 32usize]) -> anyhow::Result<Self> {
        let key = Ed25519PublicKey::from_slice(&bytes)?;
        Ok(key.into())
    }

    pub fn as_bytes(&self) -> [u8; 32usize] {
        self.key.as_bytes().clone()
    }

    pub fn from_base64(base64_key: String) -> anyhow::Result<Self> {
        let key = Ed25519PublicKey::from_base64(&base64_key)?;
        Ok(key.into())
    }

    pub fn to_base64(&self) -> String {
        self.key.to_base64()
    }

    /// Throws on mismatched signatures
    pub fn verify(
        &self,
        message: String,
        signature: VodozemacEd25519Signature,
    ) -> anyhow::Result<()> {
        self.key.verify(&message.as_bytes(), &signature.signature)?;
        Ok(())
    }
}

impl From<Ed25519PublicKey> for VodozemacEd25519PublicKey {
    fn from(key: Ed25519PublicKey) -> Self {
        VodozemacEd25519PublicKey {
            key: RustOpaqueNom::new(key),
        }
    }
}

pub struct VodozemacCurve25519PublicKey {
    pub key: RustOpaqueNom<Curve25519PublicKey>,
}

impl From<Curve25519PublicKey> for VodozemacCurve25519PublicKey {
    fn from(key: Curve25519PublicKey) -> Self {
        VodozemacCurve25519PublicKey {
            key: RustOpaqueNom::new(key),
        }
    }
}

impl VodozemacCurve25519PublicKey {
    pub const LENGTH: usize = 32usize;

    pub fn from_slice(bytes: [u8; 32usize]) -> anyhow::Result<Self> {
        let key = Curve25519PublicKey::from_slice(&bytes)?;
        Ok(key.into())
    }

    pub fn as_bytes(&self) -> [u8; 32usize] {
        self.key.to_bytes()
    }

    pub fn from_base64(base64_key: String) -> anyhow::Result<Self> {
        let key = Curve25519PublicKey::from_base64(&base64_key)?;
        Ok(key.into())
    }

    pub fn to_base64(&self) -> String {
        self.key.to_base64()
    }
}

pub struct VodozemacIdentityKeys {
    pub ed25519: VodozemacEd25519PublicKey,
    pub curve25519: VodozemacCurve25519PublicKey,
}
impl From<IdentityKeys> for VodozemacIdentityKeys {
    fn from(key: IdentityKeys) -> Self {
        VodozemacIdentityKeys {
            ed25519: key.ed25519.into(),
            curve25519: key.curve25519.into(),
        }
    }
}

pub struct VodozemacOlmMessage {
    pub msg: RustOpaqueNom<OlmMessage>,
}

impl From<OlmMessage> for VodozemacOlmMessage {
    fn from(msg: OlmMessage) -> Self {
        VodozemacOlmMessage {
            msg: RustOpaqueNom::new(msg),
        }
    }
}

impl VodozemacOlmMessage {
    pub fn message_type(&self) -> usize {
        self.msg.message_type().into()
    }

    pub fn message(&self) -> String {
        match &*self.msg {
            OlmMessage::Normal(m) => m.to_base64(),
            OlmMessage::PreKey(m) => m.to_base64(),
        }
    }

    pub fn from_parts(message_type: usize, ciphertext: String) -> anyhow::Result<Self> {
        let ciphertext_vec = base64_decode(&ciphertext)?;
        Ok(OlmMessage::from_parts(message_type, ciphertext_vec.as_slice())?.into())
    }
}

pub struct VodozemacSession {
    pub session: RustOpaqueNom<RwLock<Session>>,
}

impl From<Session> for VodozemacSession {
    fn from(key: Session) -> Self {
        VodozemacSession {
            session: RustOpaqueNom::new(RwLock::new(key)),
        }
    }
}

impl VodozemacSession {
    pub fn session_id(&self) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .session_id()
    }

    pub fn has_received_message(&self) -> bool {
        self.session
            .read()
            .expect("Failed to read session")
            .has_received_message()
    }

    pub fn encrypt(&self, plaintext: String) -> VodozemacOlmMessage {
        self.session
            .write()
            .expect("Failed to write session")
            .encrypt(plaintext)
            .into()
    }

    pub fn decrypt(&self, message: VodozemacOlmMessage) -> anyhow::Result<String> {
        Ok(String::from_utf8(
            self.session
                .write()
                .expect("Failed to write session")
                .decrypt(&message.msg)?,
        )?)
    }

    pub fn pickle_encrypted(&self, pickle_key: [u8; 32usize]) -> String {
        self.session
            .read()
            .expect("Failed to read session")
            .pickle()
            .encrypt(&pickle_key)
    }

    pub fn from_pickle_encrypted(
        pickle: String,
        pickle_key: [u8; 32usize],
    ) -> anyhow::Result<Self> {
        Ok(Self {
            session: RustOpaqueNom::new(RwLock::new(Session::from(SessionPickle::from_encrypted(
                &pickle,
                &pickle_key,
            )?))),
        })
    }

    pub fn from_olm_pickle_encrypted(pickle: String, pickle_key: Vec<u8>) -> anyhow::Result<Self> {
        Ok(Self {
            session: RustOpaqueNom::new(RwLock::new(Session::from_libolm_pickle(
                &pickle,
                &pickle_key,
            )?)),
        })
    }

    pub fn session_config(&self) -> VodozemacOlmSessionConfig {
        self.session
            .read()
            .expect("Failed to read session")
            .session_config()
            .into()
    }
    // pub fn session_keys(&self) -> SessionKeys
}

pub struct VodozemacOneTimeKey {
    pub keyid: String,
    pub key: VodozemacCurve25519PublicKey,
}

pub struct VodozemacOlmSessionCreationResult {
    pub session: VodozemacSession,
    pub plaintext: String,
}

pub struct VodozemacAccount {
    pub account: RustOpaqueNom<std::sync::RwLock<Account>>,
}

impl VodozemacAccount {
    pub fn new() -> Self {
        Self {
            account: RustOpaqueNom::new(RwLock::new(Account::new())),
        }
    }

    pub fn max_number_of_one_time_keys(&self) -> usize {
        self.account
            .read()
            .expect("Failed to read account")
            .max_number_of_one_time_keys()
    }

    pub fn generate_fallback_key(&self) -> Option<String> {
        self.account
            .write()
            .expect("Failed to write account")
            .generate_fallback_key()
            .map(|k| k.to_base64())
    }

    pub fn forget_fallback_key(&self) -> bool {
        self.account
            .write()
            .expect("Failed to write account")
            .forget_fallback_key()
    }

    pub fn generate_one_time_keys(&self, count: usize) {
        self.account
            .write()
            .expect("Failed to write account")
            .generate_one_time_keys(count);
    }

    pub fn remove_one_time_key(&self, public_key: String) -> Vec<u8> {
        self.account
            .write()
            .expect("Failed to write account")
            .remove_one_time_key(Curve25519PublicKey::from_base64(&public_key).unwrap())
            .unwrap()
            .to_bytes()
            .to_vec()
    }

    pub fn mark_keys_as_published(&self) {
        self.account
            .write()
            .expect("Failed to write account")
            .mark_keys_as_published()
    }

    pub fn ed25519_key(&self) -> VodozemacEd25519PublicKey {
        self.account
            .read()
            .expect("Failed to read account")
            .ed25519_key()
            .into()
    }

    pub fn curve25519_key(&self) -> VodozemacCurve25519PublicKey {
        self.account
            .read()
            .expect("Failed to read account")
            .curve25519_key()
            .into()
    }

    pub fn identity_keys(&self) -> VodozemacIdentityKeys {
        self.account
            .read()
            .expect("Failed to read account")
            .identity_keys()
            .into()
    }

    pub fn one_time_keys(&self) -> Vec<VodozemacOneTimeKey> {
        self.account
            .read()
            .expect("Failed to read account")
            .one_time_keys()
            .into_iter()
            .map(|(k, v)| VodozemacOneTimeKey {
                keyid: k.to_base64(),
                key: v.into(),
            })
            .collect::<Vec<VodozemacOneTimeKey>>()
    }

    pub fn fallback_key(&self) -> Vec<VodozemacOneTimeKey> {
        self.account
            .read()
            .expect("Failed to read account")
            .fallback_key()
            .into_iter()
            .map(|(k, v)| VodozemacOneTimeKey {
                keyid: k.to_base64(),
                key: v.into(),
            })
            .collect::<Vec<VodozemacOneTimeKey>>()
    }

    pub fn sign(&self, message: String) -> VodozemacEd25519Signature {
        self.account
            .read()
            .expect("Failed to read account")
            .sign(&message)
            .into()
    }

    pub fn create_outbound_session(
        &self,
        config: VodozemacOlmSessionConfig,
        identity_key: VodozemacCurve25519PublicKey,
        one_time_key: VodozemacCurve25519PublicKey,
    ) -> VodozemacSession {
        self.account
            .read()
            .expect("Failed to read account")
            .create_outbound_session(*config.config, *identity_key.key, *one_time_key.key)
            .into()
    }

    pub fn create_inbound_session(
        &self,
        their_identity_key: VodozemacCurve25519PublicKey,
        pre_key_message_base64: String,
    ) -> anyhow::Result<VodozemacOlmSessionCreationResult> {
        let res = self
            .account
            .write()
            .expect("Failed to write account")
            .create_inbound_session(
                *their_identity_key.key,
                &vodozemac::olm::PreKeyMessage::from_base64(&pre_key_message_base64)?,
            )?;
        Ok(VodozemacOlmSessionCreationResult {
            session: res.session.into(),
            plaintext: String::from_utf8(res.plaintext)?,
        })
    }

    pub fn pickle_encrypted(&self, pickle_key: [u8; 32usize]) -> String {
        self.account
            .read()
            .expect("Failed to read account")
            .pickle()
            .encrypt(&pickle_key)
    }

    pub fn from_pickle_encrypted(
        pickle: String,
        pickle_key: [u8; 32usize],
    ) -> anyhow::Result<Self> {
        Ok(Self {
            account: RustOpaqueNom::new(RwLock::new(Account::from(AccountPickle::from_encrypted(
                &pickle,
                &pickle_key,
            )?))),
        })
    }

    pub fn from_olm_pickle_encrypted(pickle: String, pickle_key: Vec<u8>) -> anyhow::Result<Self> {
        Ok(Self {
            account: RustOpaqueNom::new(RwLock::new(Account::from_libolm_pickle(
                &pickle,
                &pickle_key,
            )?)),
        })
    }
}

pub struct VodozemacSas {
    sas: Sas,
}

impl VodozemacSas {
    pub fn new() -> Self {
        Self { sas: Sas::new() }
    }

    pub fn public_key(&self) -> String {
        self.sas.public_key().to_base64()
    }

    pub fn establish_sas_secret(
        self,
        other_public_key: &str,
    ) -> anyhow::Result<VodozemacEstablishedSas> {
        let result = self.sas.diffie_hellman_with_raw(other_public_key)?;
        Ok(VodozemacEstablishedSas {
            established_sas: RustOpaqueNom::new(result),
        })
    }
}

pub struct VodozemacEstablishedSas {
    pub established_sas: RustOpaqueNom<EstablishedSas>,
}

impl VodozemacEstablishedSas {
    pub fn generate_bytes(&self, info: &str, length: u32) -> anyhow::Result<Vec<u8>> {
        Ok(self.established_sas.bytes_raw(info, length as usize)?)
    }

    pub fn calculate_mac(&self, input: &str, info: &str) -> anyhow::Result<String> {
        Ok(self.established_sas.calculate_mac(input, info).to_base64())
    }

    pub fn calculate_mac_deprecated(&self, input: &str, info: &str) -> anyhow::Result<String> {
        Ok(self
            .established_sas
            .calculate_mac_invalid_base64(input, info))
    }

    pub fn verify_mac(&self, input: &str, info: &str, mac: &str) -> anyhow::Result<()> {
        Ok(self
            .established_sas
            .verify_mac(input, info, &Mac::from_base64(mac)?)?)
    }
}

pub struct VodozemacPkMessage {
    pub ciphertext: Vec<u8>,
    pub mac: Vec<u8>,
    pub ephemeral_key: VodozemacCurve25519PublicKey,
}

impl From<PkMessage> for VodozemacPkMessage {
    fn from(message: PkMessage) -> Self {
        Self {
            ciphertext: message.ciphertext,
            mac: message.mac,
            ephemeral_key: message.ephemeral_key.into(),
        }
    }
}

impl Into<PkMessage> for VodozemacPkMessage {
    fn into(self) -> PkMessage {
        PkMessage {
            ciphertext: self.ciphertext,
            mac: self.mac,
            ephemeral_key: *self.ephemeral_key.key,
        }
    }
}

impl VodozemacPkMessage {
    pub fn new(
        ciphertext: Vec<u8>,
        mac: Vec<u8>,
        ephemeral_key: VodozemacCurve25519PublicKey,
    ) -> Self {
        Self {
            ciphertext,
            mac,
            ephemeral_key,
        }
    }

    pub fn from_base64(ciphertext: &str, mac: &str, ephemeral_key: &str) -> anyhow::Result<Self> {
        Ok(Self {
            ciphertext: base64_decode(ciphertext)?,
            mac: base64_decode(mac)?,
            ephemeral_key: Curve25519PublicKey::from_base64(ephemeral_key)?.into(),
        })
    }

    pub fn to_base64(&self) -> anyhow::Result<(String, String, String)> {
        Ok((
            base64_encode(&self.ciphertext),
            base64_encode(&self.mac),
            self.ephemeral_key.to_base64(),
        ))
    }
}

pub struct VodozemacPkEncryption {
    pub pk_encryption: RustOpaqueNom<PkEncryption>,
}

impl VodozemacPkEncryption {
    pub fn from_key(public_key: VodozemacCurve25519PublicKey) -> Self {
        Self {
            pk_encryption: RustOpaqueNom::new(PkEncryption::from_key(*public_key.key)),
        }
    }

    pub fn encrypt(&self, message: String) -> VodozemacPkMessage {
        self.pk_encryption.encrypt(message.as_ref()).into()
    }
}

pub struct VodozemacPkDecryption {
    pub pk_decryption: RustOpaqueNom<PkDecryption>,
}

impl VodozemacPkDecryption {
    pub fn new() -> Self {
        Self {
            pk_decryption: RustOpaqueNom::new(PkDecryption::new()),
        }
    }

    pub fn from_key(secret_key: &[u8; 32]) -> Self {
        Self {
            pk_decryption: RustOpaqueNom::new(PkDecryption::from_key(
                Curve25519SecretKey::from_slice(secret_key),
            )),
        }
    }

    pub fn public_key(&self) -> String {
        self.pk_decryption.public_key().to_base64()
    }

    pub fn private_key(&self) -> Vec<u8> {
        self.pk_decryption.secret_key().to_bytes().to_vec()
    }

    pub fn decrypt(&self, message: VodozemacPkMessage) -> anyhow::Result<String> {
        let msg: PkMessage = message.into();
        let temp = self.pk_decryption.decrypt(&msg)?;
        Ok(String::from_utf8(temp)?)
    }

    pub fn to_libolm_pickle(&self, pickle_key: [u8; 32usize]) -> String {
        self.pk_decryption
            .to_libolm_pickle(&pickle_key)
            .expect("Failed to pickle PkDecryption")
    }

    pub fn from_libolm_pickle(pickle: String, pickle_key: Vec<u8>) -> anyhow::Result<Self> {
        Ok(Self {
            pk_decryption: RustOpaqueNom::new(PkDecryption::from_libolm_pickle(
                &pickle,
                &pickle_key,
            )?),
        })
    }
}

pub struct PkSigning {
    inner: Ed25519SecretKey,
    public_key: Ed25519PublicKey,
}

impl PkSigning {
    pub fn new() -> Self {
        let secret_key = Ed25519SecretKey::new();
        let public_key = secret_key.public_key();
        Self {
            inner: secret_key,
            public_key,
        }
    }

    pub fn from_secret_key(key: &str) -> anyhow::Result<Self> {
        let key = Ed25519SecretKey::from_base64(key)?;
        let public_key = key.public_key();
        Ok(Self {
            inner: key,
            public_key,
        })
    }

    pub fn secret_key(&self) -> String {
        self.inner.to_base64()
    }

    pub fn public_key(&self) -> VodozemacEd25519PublicKey {
        VodozemacEd25519PublicKey {
            key: RustOpaqueNom::new(self.public_key),
        }
    }

    pub fn sign(&self, message: &str) -> VodozemacEd25519Signature {
        VodozemacEd25519Signature {
            signature: RustOpaqueNom::new(self.inner.sign(message.as_bytes())),
        }
    }
}

pub fn sha256(input: Vec<u8>) -> Vec<u8> {
    Sha256::digest(input).to_vec()
}

pub fn sha512(input: Vec<u8>) -> Vec<u8> {
    Sha512::digest(input).to_vec()
}

/// Calculate HMAC with sha256.
pub fn hmac(key: &[u8], input: &[u8]) -> anyhow::Result<Vec<u8>> {
    type HmacSha256 = hmac::Hmac<Sha256>;
    let mut mac = HmacSha256::new_from_slice(key)?;
    mac.update(input);
    let result = mac.finalize();
    Ok(result.into_bytes().to_vec())
}

/// For sending encrypted attachments.
/// https://spec.matrix.org/v1.16/client-server-api/#sending-encrypted-attachments
/// In order to achieve this, a client should generate a single-use 256-bit AES key,
/// and encrypt the file using AES-CTR.
/// The counter should be 64-bit long, starting at 0 and prefixed by a random 64-bit
/// Initialization Vector (IV), which together form a 128-bit unique counter block.
pub fn aes_ctr(input: &[u8], key: &[u8], iv: &[u8]) -> Vec<u8> {
    type Aes256Ctr64BE = ctr::Ctr64BE<aes::Aes256>;
    let mut cipher = Aes256Ctr64BE::new(key.into(), iv.into());
    let mut buf = input.to_vec();
    cipher.apply_keystream(&mut buf);
    return buf;
}

/// Calculate pbkdf2 with fixes length of 256:
pub fn pbkdf2(passphrase: &[u8], salt: &[u8], iterations: u32) -> anyhow::Result<Vec<u8>> {
    let result = pbkdf2_array::<hmac::Hmac<Sha512>, 32>(passphrase, salt, iterations)?.to_vec();
    Ok(result)
}
