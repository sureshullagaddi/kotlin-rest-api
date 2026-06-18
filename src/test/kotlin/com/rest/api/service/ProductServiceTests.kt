package com.rest.api.service

import com.rest.api.entity.Product
import com.rest.api.repository.ProductRepository
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.BeforeEach
import org.mockito.Mockito.*
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.mock.mockito.MockBean
import java.math.BigDecimal
import java.time.LocalDateTime
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

@SpringBootTest
class ProductServiceTests {

    @Autowired
    private lateinit var productService: ProductService

    @MockBean
    private lateinit var productRepository: ProductRepository

    private lateinit var testProduct: Product

    @BeforeEach
    fun setUp() {
        testProduct = Product(
            id = 1L,
            name = "Test Product",
            price = BigDecimal("99.99"),
            createdAt = LocalDateTime.now(),
            updatedAt = LocalDateTime.now()
        )
    }

    @Test
    fun `getAllProducts should return list from repository`() {
        `when`(productRepository.findAll()).thenReturn(listOf(testProduct))

        val result = productService.getAllProducts()

        assertEquals(1, result.size)
        assertEquals("Test Product", result[0].name)
        verify(productRepository, times(1)).findAll()
    }

    @Test
    fun `getProductById should return product when found`() {
        `when`(productRepository.findById(1L)).thenReturn(java.util.Optional.of(testProduct))

        val result = productService.getProductById(1L)

        assertNotNull(result)
        assertEquals("Test Product", result.name)
        verify(productRepository, times(1)).findById(1L)
    }

    @Test
    fun `getProductById should return null when not found`() {
        `when`(productRepository.findById(999L)).thenReturn(java.util.Optional.empty())

        val result = productService.getProductById(999L)

        assertNull(result)
        verify(productRepository, times(1)).findById(999L)
    }

    @Test
    fun `createProduct should save and return product`() {
        `when`(productRepository.save(any())).thenReturn(testProduct)

        val result = productService.createProduct(testProduct)

        assertNotNull(result)
        assertEquals("Test Product", result.name)
        verify(productRepository, times(1)).save(any())
    }

    @Test
    fun `updateProduct should update and return product`() {
        val updatedProduct = testProduct.copy(name = "Updated Product")
        `when`(productRepository.findById(1L)).thenReturn(java.util.Optional.of(testProduct))
        `when`(productRepository.save(any())).thenReturn(updatedProduct)

        val result = productService.updateProduct(1L, updatedProduct)

        assertNotNull(result)
        assertEquals("Updated Product", result.name)
        verify(productRepository, times(1)).findById(1L)
        verify(productRepository, times(1)).save(any())
    }

    @Test
    fun `deleteProduct should call repository delete`() {
        doNothing().`when`(productRepository).deleteById(1L)

        productService.deleteProduct(1L)

        verify(productRepository, times(1)).deleteById(1L)
    }

    @Test
    fun `getProductByName should return product when found`() {
        `when`(productRepository.findByName("Test Product")).thenReturn(testProduct)

        val result = productService.getProductByName("Test Product")

        assertNotNull(result)
        assertEquals("Test Product", result.name)
        verify(productRepository, times(1)).findByName("Test Product")
    }
}

