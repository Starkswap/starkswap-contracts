use starknet::StorageAccess;
use starknet::StorageBaseAddress;
use starknet::SyscallResult;
use starknet::storage_read_syscall;
use starknet::storage_write_syscall;
use starknet::storage_address_from_base_and_offset;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;


#[derive(Serde, Copy, Drop)]
struct Observation {
    block_timestamp: u64,
    cumulative_base_reserve: u256,
    cumulative_quote_reserve: u256,
}

impl ObservationStorageAccess of StorageAccess<Observation> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult::<Observation> {
        Result::Ok(
            Observation {
                block_timestamp: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 0_u8)
                )?
                    .try_into()
                    .unwrap(),
                cumulative_base_reserve: u256 {
                    low: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 1_u8)
                    )?
                        .try_into()
                        .unwrap(),
                    high: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 2_u8)
                    )?
                        .try_into()
                        .unwrap()
                    }, cumulative_quote_reserve: u256 {
                    low: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 3_u8)
                    )?
                        .try_into()
                        .unwrap(),
                    high: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 4_u8)
                    )?
                        .try_into()
                        .unwrap()
                }
            }
        )
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Observation
    ) -> SyscallResult::<()> {
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 0_u8),
            value.block_timestamp.into()
        )?;

        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 1_u8),
            value.cumulative_base_reserve.low.into()
        )?;
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 2_u8),
            value.cumulative_base_reserve.high.into()
        )?;

        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 3_u8),
            value.cumulative_quote_reserve.low.into()
        )?;
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 4_u8),
            value.cumulative_quote_reserve.high.into()
        )
    }
}
